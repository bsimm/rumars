# frozen_string_literal: true

require_relative 'textwm/window'

module RuMARS
  class ConsoleWindow < TextWM::Window
    attr_reader :current_warrior

    def initialize(textwm, mars)
      super(textwm, 'Console Window')
      @mars = mars
      @show_cursor = true

      # Certain commands like 'list' focus on a certain warrior. By default,
      # it is the more recently loaded warrior. Use the 'focus' command to
      # change the current warrior.
      @current_warrior = nil

      @command = ''
    end

    def resize(col, row, width, height)
      super
      prompt
    end

    def getch(char)
      terminate = false

      case char
      when 'Return'
        puts
        terminate = true unless execute(@command)
        @command = ''
        prompt
      when 'Backspace'
        unless @command.empty?
          @command = @command[0..-2]
          @virt_term.backspace
        end
      else
        if char.length == 1
          @command += char
          print char
        end
      end

      !terminate
    end

    private

    def prompt
      print("MARS>> #{@command}")
    end

    def execute(command)
      args = command.split(/\s+/)

      case args.shift
      when 'battle', 'ba'
        @mars.scheduler.battle
      when 'break', 'br'
        add_breakpoint(args)
      when 'debug'
        @mars.debug_level = args.first&.to_i || 0
      when 'dump', 'du'
        @mars.memory_core.dump(@scheduler.program_counters)
      when 'exit', 'ex'
        return false
      when 'focus', 'fo'
        change_current_warrior(args.first&.to_i)
      when 'list', 'li'
        if (address = resolve_label(args.first))
          @mars.core_window.show_address = address
        end
      when 'load', 'lo'
        load_warriors(args)
      when 'pcs'
        list_program_counters
      when 'run', 'ru'
        @mars.core_window.show_address = nil
        @mars.scheduler.run(args.first&.to_i || -1)
      when 'step', 'st'
        @mars.core_window.show_address = nil
        prev_debug_level = @mars.debug_level
        @mars.debug_level = 3
        @mars.scheduler.step
        @mars.debug_level = prev_debug_level
      when 'unbreak', 'un'
        @mars.scheduler.delete_breakpoint(args.first&.to_i)
      else
        puts "Unknown command: #{command}"
      end

      true
    end

    def load_warriors(files)
      if files.empty?
        puts 'You must specify at least one Redcode file'
        return
      end

      files.each do |file|
        @mars.load_warrior(file)
      end
    end

    def change_current_warrior(index)
      unless (warrior = @scheduler.get_warrior_by_index(index - 1))
        puts "Unknown warrior #{index}"
      end

      @current_warrior = warrior
    end

    def list_program_counters
      return unless @current_warrior

      puts @scheduler.program_counters(@current_warrior).join(' ')
    end
    def add_breakpoint(breakpoints)
      if breakpoints.empty?
        puts 'You must specify a memory core address or a label name to set a breakpoint'
        return
      end

      breakpoints.each do |breakpoint|
        if (address = resolve_label(breakpoint))
          @mars.scheduler.add_breakpoint(address)
        end
      end
    end

    def remove_breakpoint(breakpoints)
      if breakpoints.empty?
        puts 'You must specify a memory core address or a label name to set a breakpoint'
        return
      end

      breakpoints.each do |breakpoint|
        if (address = resolve_label(breakpoint))
          @mars.scheduler.remove_breakpoint(address)
        end
      end
    end

    def resolve_label(label_or_address)
      case label_or_address
      when /\A\d+\z/
        if (address = label_or_address.to_i) >= MemoryCore.size
          puts "Breakpoint address #{address} must be between 0 and #{MemoryCore.size - 1}"
          return nil
        end

        return address.to_i
      when /\A[A-Za-z_][A-Za-z0-9_]*\z/
        # We need to have at least one program loaded
        return nil unless @current_warrior.program

        if (address = @current_warrior.program.labels[label_or_address])
          return MemoryCore.fold(address + @current_warrior.base_address)
        end

        puts "Unknown program label '#{label_or_address}'"
      else
        puts 'You must specify a memory core address or a label of the currently selected program'
      end

      nil
    end
  end
end
