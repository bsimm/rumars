# frozen_string_literal: true

require_relative 'textwm/window'
require_relative 'format'

module RuMARS
  class ConsoleWindow < TextWM::Window
    attr_accessor :current_warrior

    include Format

    HISTORY_SIZE = 100

    def initialize(textwm, mars)
      super(textwm, 'Console Window')
      @mars = mars
      @show_cursor = true

      # Certain commands like 'list' focus on a certain warrior. By default,
      # it is the more recently loaded warrior. Use the 'focus' command to
      # change the current warrior.
      @current_warrior = nil

      @command = ''
      @saved_command = nil
      @command_history = []
      @history_index = -1
      prompt
    end

    def getch(char)
      case char
      when 'ArrowUp'
        return if @history_index >= @command_history.length - 1

        # If we show the most recent history command, we store the currently typed
        # command in the saved command buffer.
        @saved_command = @command if @history_index == -1

        @command = @command_history[@history_index += 1]

        @virt_term.clear_row
        prompt
      when 'ArrowDown'
        return if @history_index.negative? || (@history_index.zero? && @saved_command.nil?)

        if @history_index.zero?
          # We have listed the most recent command from the history buffer already.
          # Now restore the command from the saved command buffer.
          @command = @saved_command
          @saved_command = nil
          @history_index = -1
        else
          @command = @command_history[@history_index -= 1]
        end

        @virt_term.clear_row
        prompt
      when 'Return'
        puts
        @command_history.unshift(@command)
        @command_history.delete_at(HISTORY_SIZE) if @command_history.length >= HISTORY_SIZE
        @history_index = -1
        @saved_command = nil
        execute(@command)
        @command = ''
        prompt
      when 'Backspace'
        unless @command.empty?
          @command = @command[0..-2]
          @virt_term.backspace
        end
      else
        if char.length == 1 && char.ord >= 32
          @command += char
          print char
        # else
        #   print "[#{char.gsub(/\e/, '\e')}]"
        end
      end
    end

    def step
      # Ensure the core window centers the current program counter
      @mars.core_window.show_address = nil
      # Ensure the register window shows the latest trace
      @mars.register_window.trace_index = -1
      prev_debug_level = @mars.debug_level
      @mars.debug_level = 3
      @mars.scheduler.step
      @mars.debug_level = prev_debug_level
    end

    def run(args = [])
      puts 'Type CTRL-C to interrupt the running warrior(s)'
      @textwm.update_windows

      @mars.core_window.show_address = nil
      @mars.scheduler.run(args.first&.to_i || -1)
    end

    def toggle_breakpoint(args = [])
      if args.empty?
        unless (address = @mars.scheduler.program_counters(@current_warrior).first)
          puts 'You must specify a memory core address or a label name to set a breakpoint'
          return
        end
      else
        return unless (address = parse_address_expression(args.join(' ')))
      end

      @mars.scheduler.toggle_breakpoint(address)
    end

    def restart
      @mars.restart
      @mars.reload_warriors_into_core
    end

    def reload
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
        toggle_breakpoint(args)
      when 'debug'
        @mars.debug_level = args.first&.to_i || 0
      when 'exit', 'ex'
        @textwm.exit_application
      when 'focus', 'fo'
        change_current_warrior(args.first&.to_i)
      when 'list', 'li'
        list(args)
      when 'load', 'lo'
        load_warriors(args)
      when 'pcs'
        list_program_counters
      when 'peek', 'pe'
        peek(args)
      when 'poke', 'po'
        poke(args)
      when 'restart', 're'
        restart
      when 'run', 'ru'
        run(args)
      when 'step', 'st'
        step
      else
        puts "Unknown command: #{command}"
      end
    end

    def load_warriors(files)
      if files.empty?
        puts 'You must specify at least one Redcode file'
        return
      end

      files.each do |file|
        @current_warrior = @mars.load_warrior(file)
      end
    end

    def change_current_warrior(index)
      unless (warrior = @scheduler.get_warrior_by_index(index - 1))
        puts "Unknown warrior #{index}"
      end

      @current_warrior = warrior
    end

    def list(args)
      return unless (address = parse_address_expression(args.join(' ')))

      @mars.core_window.show_address = address
    end

    def list_program_counters
      return unless @current_warrior

      puts @mars.scheduler.program_counters(@current_warrior).join(' ')
    end

    def peek(args)
      return unless (address = parse_address_expression(args.join(' ')))

      begin
        puts "#{aformat(address)}: #{@mars.memory_core.peek(address)}"
      rescue ArgumentError => e
        puts e.message
      end
    end

    def poke(args)
      return unless (address = resolve_label(args.first))

      instruction_text = args[1..].join(' ')

      parser = Parser.new({}, $stdout)

      begin
        unless (instruction = parser.parse(instruction_text, :opcode_and_operands))
          puts 'You must specify a valid instruction'
          return
        end
      rescue Parser::ParseError => e
        puts e.message
        return
      end

      begin
        instruction.evaluate_expressions(@mars.current_warrior&.program&.labels || [], address)
      rescue Expression::ExpressionError => e
        puts e.message
        return
      end

      # Set the ownership of the new instruction to the current warrior
      instruction.pid = @mars.memory_core.pid(@mars.current_warrior) || 0

      @mars.memory_core.poke(address, instruction)
      @mars.core_window.show_address = address
    end

    def parse_address_expression(term)
      parser = Parser.new({}, $stdout)
      begin
        unless (address_expression = parser.parse(term, :expr))
          puts 'You must specify an epression that resolves to an address'
          return nil
        end
      rescue Parser::ParseError => e
        puts e.message
        return nil
      end

      begin
        address = address_expression.eval(@mars.current_warrior&.program&.labels || [])
      rescue Expression::ExpressionError => e
        puts "Error in address expression: #{e.message}"
        return nil
      end

      MemoryCore.fold(address)
    end

    def resolve_label(label_or_address)
      case label_or_address
      when Integer
        return label_or_address
      when /\A\d+\z/
        if (address = label_or_address.to_i) >= MemoryCore.size
          puts "Address #{address} must be between 0 and #{MemoryCore.size - 1}"
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
