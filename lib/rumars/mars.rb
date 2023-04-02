# frozen_string_literal: true

require 'readline'

require_relative 'settings'
require_relative 'memory_core'
require_relative 'scheduler'
require_relative 'warrior'
require_relative 'tracer'
require_relative 'textwm/textwm'
require_relative 'core_window'
require_relative 'log_window'
require_relative 'console_window'
require_relative 'register_window'

module RuMARS
  # Memory Array Redcode Simulator
  # https://vyznev.net/corewar/guide.html
  # http://www.koth.org/info/icws94.html
  class MARS
    attr_reader :debug_level, :settings, :memory_core, :scheduler, :core_window, :console_window, :register_window

    def initialize(argv = [])
      @old_stdout = nil
      @settings = Settings.new(core_size: 8000, max_cycles: 80_000,
                               max_processes: 8000, max_length: 100, min_distance: 100)

      @memory_core = MemoryCore.new(@settings.core_size)
      @scheduler = Scheduler.new(@memory_core, @settings.min_distance)
      @tracer = Tracer.new
      self.debug_level = 0

      @textwm = TextWM::WindowManager.new
      setup_windows

      # Load all the Redcode files passed via the command line.
      argv.each do |file|
        @console_window.current_warrior = load_warrior(file) if file[0] != '-' && file[-4..] == '.red'
      end
    end

    def add_warrior(warrior)
      if (length = warrior.program.instructions.length) > @settings.max_length
        puts "Program of warrior #{warrior.name} must not be longer than " \
             "#{@settings.max_length} instructions. I has #{length} instructions."
        return
      end

      @scheduler.add_warrior(warrior)
      warrior.max_tasks = @settings.max_processes
    end

    def run(max_cycles = @settings.max_cycles)
      @scheduler.run(max_cycles)
    end

    def event_loop
      @textwm.event_loop
    ensure
      $stdout = @old_stdout if @old_stdout
    end

    def cycles
      @scheduler.cycles
    end

    def debug_level=(level)
      @debug_level = level
      @memory_core.tracer = level.positive? ? @tracer : nil
      @scheduler.tracer = level.positive? ? @tracer : nil
      Instruction.tracer = level.positive? ? @tracer : nil
    end

    def load_warrior(file)
      warrior = Warrior.new("Player #{@scheduler.warrior_count}")
      return nil unless warrior.parse_file(file, @settings, @log_window)

      @scheduler.add_warrior(warrior)

      warrior
    end

    def current_warrior
      @console_window&.current_warrior
    end

    private

    def setup_windows
      vsplits = @textwm.split(:vertical, nil, 10)
      hsplits = vsplits.assign(0, TextWM::Splits.new(:horizontal, 0.5, nil))
      vsplits.assign(1, @console_window = ConsoleWindow.new(@textwm, self))

      hsplits.assign(0, @core_window = CoreWindow.new(@textwm, self))
      reg_log_splits = hsplits.assign(1, TextWM::Splits.new(:vertical, 12, nil))
      reg_log_splits.assign(0, @register_window = RegisterWindow.new(@textwm, @tracer))
      reg_log_splits.assign(1, @log_window = LogWindow.new(@textwm))

      @textwm.resize
      @textwm.activate_window(@console_window)

      @scheduler.logger = @log_window
      @old_stdout = $stdout
      $stdout = @log_window
    end
  end
end
