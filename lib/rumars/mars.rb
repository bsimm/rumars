# frozen_string_literal: true

require_relative 'memory_core'
require_relative 'scheduler'
require_relative 'warrior'

module RuMARS
  # Memory Array Redcode Simulator
  # https://vyznev.net/corewar/guide.html
  # http://www.koth.org/info/icws94.html
  class MARS
    attr_reader :debug_level

    def initialize(argv = [])
      @core_size = 800
      @memory_core = MemoryCore.new(@core_size)
      @scheduler = Scheduler.new(@memory_core)
      self.debug_level = 0

      # Certain commands like 'list' focus on a certain warrior. By default,
      # it is the more recently loaded warrior. Use the 'focus' command to
      # change the current warrior.
      @current_warrior = nil

      # Load all the Redcode files passed via the command line.
      argv.each do |file|
        load_warrior(file) if file[0] != '-' && file[-4..] == '.red'
      end
    end

    def add_warrior(warrior)
      @scheduler.add_warrior(warrior)
    end

    def run(max_cycles = 800)
      @scheduler.run(max_cycles)
    end

    def repl
      loop do
        print 'MARS>> '
        command = $stdin.gets.chomp

        break unless execute(command)
      end
    end

    def cycles
      @scheduler.cycles
    end

    def debug_level=(level)
      @debug_level = level
      @memory_core.debug_level = level
      @scheduler.debug_level = level
      Instruction.debug_level = level
    end

    private

    def execute(command)
      args = command.split(/\s+/)

      case args.shift
      when 'battle', 'ba'
        @scheduler.battle
      when 'break', 'br'
        add_breakpoint(args)
      when 'debug'
        self.debug_level = args.first&.to_i || 0
      when 'dump', 'du'
        @memory_core.dump(@scheduler.program_counters)
      when 'exit', 'ex'
        return false
      when 'focus', 'fo'
        change_current_warrior(args.first&.to_i)
      when 'list', 'li'
        if (address = resolve_label(args.first))
          @memory_core.list(@scheduler.program_counters, @current_warrior,
                            address)
        end
      when 'load', 'lo'
        load_warriors(args)
      when 'pcs'
        list_program_counters
      when 'run', 'ru'
        @scheduler.run(args.first&.to_i || -1)
      when 'step', 'st'
        prev_debug_level = @debug_level
        self.debug_level = 3
        @scheduler.step
        self.debug_level = prev_debug_level
      when 'unbreak', 'un'
        @scheduler.delete_breakpoint(args.first&.to_i)
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
        load_warrior(file)
      end
    end

    def load_warrior(file)
      warrior = Warrior.new("Player #{@scheduler.warrior_count}")
      warrior.parse_file(file)
      @scheduler.add_warrior(warrior)
      @current_warrior = warrior

      warrior
    end

    private

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
          @scheduler.add_breakpoint(address)
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
          @scheduler.remove_breakpoint(address)
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
