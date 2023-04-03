# frozen_string_literal: true

require 'readline'

require_relative 'settings'
require_relative 'commandline_arguments_parser'
require_relative 'memory_core'
require_relative 'scheduler'
require_relative 'warrior'
require_relative 'tracer'
require_relative 'textwm/textwm'
require_relative 'textwm/button_row'
require_relative 'core_window'
require_relative 'log_window'
require_relative 'console_window'
require_relative 'register_window'
require_relative 'format'

module RuMARS
  # Memory Array Redcode Simulator
  # https://vyznev.net/corewar/guide.html
  # http://www.koth.org/info/icws94.html
  class MARS
    attr_reader :debug_level, :settings, :memory_core, :scheduler, :core_window, :console_window, :register_window

    include Format

    def initialize(argv = [])
      # The default settings for certain configuration options. They can be
      # changed via commandline arguments.
      @settings = Settings.new(core_size: 8000, max_cycles: 80_000,
                               max_processes: 8000, max_length: 100, min_distance: 100)
      # Process the commandline arguments to adjust configuration options.
      @files = CommandlineArgumentsParser.new(@settings).parse(argv)

      @warriors = []

      restart
    end

    def main(stdout = $stdout, stdin = $stdin)
      # Setup the user interface
      @textwm = TextWM::WindowManager.new(stdout, stdin)
      setup_windows

      begin
        # Redirect all output of 'puts' or 'print' to the @log_window
        old_stdout = $stdout
        $stdout = @log_window

        # Load all the Redcode files passed via the command line.
        @files.each do |file_name|
          @console_window.current_warrior = load_warrior(file_name)
        end

        @textwm.event_loop
      ensure
        $stdout = old_stdout
      end
    end

    def restart
      @memory_core = MemoryCore.new(@settings)
      @scheduler = Scheduler.new(@memory_core, @warriors)
      @tracer = Tracer.new
      self.debug_level = 0
    end

    def reload_warriors_into_core
      @warriors.each(&:unload_program)

      @warriors.each do |warrior|
        load_warrior_into_core(warrior)
      end
    end

    def load_warrior(file_name)
      warrior = Warrior.new("Player #{@scheduler.warrior_count}")
      register_warrior(warrior)

      return nil unless warrior.parse_file(file_name, @settings, @log_window)

      add_warrior(warrior)
    end

    def add_warrior(warrior)
      # Only needed for spec tests.
      register_warrior(warrior)

      if (length = warrior.program.instructions.length) > @settings.max_length
        @log_window.puts "Program of warrior #{warrior.name} must not be longer than " \
                         "#{@settings.max_length} instructions. I has #{length} instructions."
        return nil
      end

      warrior.max_tasks = @settings.max_processes

      load_warrior_into_core(warrior)
    end

    def load_warrior_into_core(warrior)
      unless (base_address = @memory_core.load_warrior(warrior))
        @log_window.puts "Warrior '#{warrior.name}' could not be loaded into the core"
        return false
      end

      @log_window.puts "Loaded '#{warrior.name}' into memory core at #{aformat(base_address)}"

      # Tell the core window to show the code at the base address
      @core_window.show_address = base_address

      warrior
    end

    def register_warrior(warrior)
      return if @warriors.include?(warrior)

      @warriors << warrior
    end

    def run(max_cycles = @settings.max_cycles)
      @scheduler.run(max_cycles)
    end

    def event_loop
      @textwm.event_loop
    end

    def cycles
      @scheduler.cycle_counter
    end

    def debug_level=(level)
      @debug_level = level
      @memory_core.tracer = level.positive? ? @tracer : nil
      @scheduler.tracer = level.positive? ? @tracer : nil
      Instruction.tracer = level.positive? ? @tracer : nil
    end

    def current_warrior
      @console_window&.current_warrior
    end

    private

    def setup_windows
      vsplits = @textwm.split(:vertical, nil, 10, 1)
      hsplits = vsplits.assign(0, TextWM::Splits.new(:horizontal, 50, nil))
      vsplits.assign(1, @console_window = ConsoleWindow.new(@textwm, self))
      vsplits.assign(2, TextWM::ButtonRow.new(@textwm))

      hsplits.assign(0, @core_window = CoreWindow.new(@textwm, self))
      reg_log_splits = hsplits.assign(1, TextWM::Splits.new(:vertical, 12, nil))
      reg_log_splits.assign(0, @register_window = RegisterWindow.new(@textwm, @tracer))
      reg_log_splits.assign(1, @log_window = LogWindow.new(@textwm))

      @textwm.resize
      @textwm.activate_window(@console_window)

      @scheduler.logger = @log_window
    end
  end
end
