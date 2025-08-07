#
# Copyright (c) Chris Schlaeger <cs@taskjuggler.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#
# frozen_string_literal: true

require_relative 'settings'
require_relative 'commandline_arguments_parser'
require_relative 'memory_core'
require_relative 'scheduler'
require_relative 'warrior'
require_relative 'tracer'
require_relative 'help_browser'
require_relative 'textwm/textwm'
require_relative 'textwm/panel'
require_relative 'core_window'
require_relative 'core_view_window'
require_relative 'log_window'
require_relative 'console_window'
require_relative 'register_window'
require_relative 'warriors_window'
require_relative 'format'

module RuMARS
  # Memory Array Redcode Simulator
  # https://vyznev.net/corewar/guide.html
  # http://www.koth.org/info/icws94.html
  class MARS
    attr_reader :debug_level, :settings,
                :memory_core, :scheduler, :tracer, :warriors,
                :core_window, :console_window, :log_window,
                :register_window, :warriors_window

    include Format

    # We could support more, but the user interface will become clobbered with
    # more than 4 warriors.
    MAX_WARRIORS = 4

    def initialize(argv = [])
      # The default settings for certain configuration options. They can be
      # changed via commandline arguments.
      @settings = Settings.new(
        8000, # core_size: 8000
        8000, # max_cycles: 80_000
        8000, # max_processes: 8000
        100, # max_length: 100
        100, # min_distance: 100
        4000, # read_limit: 4000
        4000, # write_limit: 4000
        1, # rounds: 1
        'ui', # start user interface
        nil, # coredump_file
        nil # trace_file
      )
      # Process the commandline arguments to adjust configuration options.
      @files = CommandlineArgumentsParser.new(@settings).parse(argv)

      if @settings[:read_limit] < @settings[:write_limit]
        warn "Read limit (#{@settings[:read_limit]}) must not be smaller " \
             "than write limit (#{@settings[:write_limit]})"
        return
      end

      @warriors = []

      restart
    end

    def main(stdout = $stdout, stdin = $stdin)
      case @settings[:mode]
      when 'ui'
        user_interace(stdout, stdin)
      when 'asm'
        assemble_files(stdout)
      when 'btl'
        return false unless assemble_files(stdout)

        battle(stdout)
      end
    end

    def user_interace(stdout, stdin)
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

    def assemble_files(stdout)
      @log_window = stdout

      @files.each do |file_name|
        return false unless load_warrior(file_name)
      end

      true
    end

    def battle(log, rounds = @settings[:rounds])
      @warriors.each(&:reset_scores)

      abort_with_ctrl_c(log, 'the battle') do
        rounds.times do |round|
          @warriors_window&.round = round
          restart
          reload_warriors_into_core
          @memory_core.io_trace = []

          trace_execution(round) do
            @settings[:max_cycles].times do |i|
              @scheduler.step
              if ((i + 1) % 10).zero?
                @warriors_window&.cycle = i
                @textwm&.update_windows
              end
            end
          end

          # Save the coredump file if the user has specified one.
          if (coredump_file = @settings[:coredump_file])
            coredump_file += round.zero? ? '' : "-#{round}"
            @memory_core.save_coredump(coredump_file)
          end

          log_round_result(log, round)
        end
      end
      @memory_core.io_trace = nil

      log_match_result(log)
    end

    def restart
      @memory_core = MemoryCore.new(@settings)
      @scheduler = Scheduler.new(@memory_core, @warriors)
      @tracer = Tracer.new
      self.debug_level = 0
    end

    def reload_warriors_into_core
      @warriors.each do |warrior|
        warrior.reload(@settings, @log_window)
      end

      @warriors.each(&:unload_program)

      @warriors.each do |warrior|
        load_warrior_into_core(warrior)
      end
    end

    def create_warrior(name)
      warrior = Warrior.new(name || "Player #{@warriors.length + 1}")
      return unless register_warrior(warrior)

      warrior.parse(";redcode\n DAT $0, $0\n", @settings, @log_window)

      add_warrior(warrior)
    end

    def load_warrior(file_name)
      warrior = Warrior.new("Player #{@warriors.length + 1}")
      return unless register_warrior(warrior)

      return nil unless warrior.parse_file(file_name, @settings, @log_window)

      add_warrior(warrior)
    end

    def add_warrior(warrior)
      # Only needed for spec tests.
      return unless register_warrior(warrior)

      if warrior.program && (length = warrior.program.instructions.length) > @settings.max_length
        @log_window.puts "Program of warrior #{warrior.name} must not be longer than " \
                         "#{@settings.max_length} instructions. I has #{length} instructions."
        return nil
      end

      warrior.max_tasks = @settings.max_processes

      load_warrior_into_core(warrior)
    end

    def run(max_cycles = @settings.max_cycles)
      @scheduler.run(max_cycles)
    end

    def trace(max_cycles = @settings.max_cycles)
      @tracer = Tracer.new
      old_debug_level = @debug_level
      self.debug_level = 1

      run(max_cycles)
      trace = @tracer.to_s

      self.debug_level = old_debug_level
      @tracer = nil

      trace
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

    def toggle_core_view
      # The core view can be invisible, small and big. The other panes will be
      # adjusted accordingly.
      current_size = @vsplits2.ratios[1]
      if current_size&.zero?
        # The core view is currently invisible. Make it small.
        @vsplits1.ratios = [nil, 10, 1]
        @vsplits2.ratios = [nil, 10]
      elsif current_size == 10
        # The core view is currently small. Make it big.
        @vsplits1.ratios = [nil, 4, 1]
        @vsplits2.ratios = [0, nil]
        @vsplits3.ratios = [0, 3]
      else
        # The core view is currently big. Hide it.
        @vsplits1.ratios = [nil, 10, 1]
        @vsplits2.ratios = [nil, 0]
        @vsplits3.ratios = [12, nil]
      end
      @textwm.resize
      @textwm.update_windows
    end

    def toggle_warriors_window
      current_size = @hsplits1.ratios[1]
      # Toggle the width between 21 and 0
      @hsplits1.ratios = [nil, current_size.zero? ? 21 : 0]

      @textwm.resize
      @textwm.update_windows
    end

    private

    def abort_with_ctrl_c(stdout, what)
      stdout.puts "Type CTRL-C to interrupt #{what}"
      Signal.trap('SIGINT') { throw :signal_interrupt }

      catch :signal_interrupt do
        yield

        Signal.trap('SIGINT', 'DEFAULT')
      end
    end

    def setup_windows
      # +-vsplits1----------------------------+
      # |+-hsplits1--------------------------+|
      # ||+-vsplits2---------------++-------+||
      # |||+-hsplits2-------------+||       |||
      # ||||+------++-vsplits3---+|||       |||
      # |||||      ||+----------+||||warrior|||
      # |||||core  |||register  |||||window |||
      # |||||window|||window    |||||       |||
      # |||||      ||+----------+||||       |||
      # |||||      ||+----------+||||       |||
      # |||||      |||log window|||||       |||
      # |||||      ||+----------+||||       |||
      # ||||+------++-vsplits3---+|||       |||
      # |||+-hsplits2-------------+||       |||
      # |||+----------------------+||       |||
      # ||||core view window      |||       |||
      # |||+----------------------+||       |||
      # ||+-vsplits2---------------++-------+||
      # |+-hsplits2--------------------------+|
      # |+-----------------------------------+|
      # ||console window                     ||
      # |+-----------------------------------+|
      # |+-----------------------------------+|
      # ||F-button panel                     ||
      # |+-----------------------------------+|
      # +-vsplits1----------------------------+
      @vsplits1 = @textwm.split(:vertical, nil, 10, 1)
      @hsplits1 = @vsplits1.assign(0, TextWM::Splits.new(:horizontal, nil, 0))
      @vsplits2 = @hsplits1.assign(0, TextWM::Splits.new(:vertical, nil, 0))
      hsplits2 = @vsplits2.assign(0, TextWM::Splits.new(:horizontal, 50, nil))
      hsplits2.assign(0, @core_window = CoreWindow.new(@textwm, self))
      @vsplits3 = hsplits2.assign(1, TextWM::Splits.new(:vertical, 12, nil))
      @vsplits3.assign(0, @register_window = RegisterWindow.new(@textwm, self))
      @vsplits3.assign(1, @log_window = LogWindow.new(@textwm))
      @vsplits2.assign(1, @core_view_window = CoreViewWindow.new(@textwm, self))
      @hsplits1.assign(1, @warriors_window = WarriorsWindow.new(@textwm, self))
      @vsplits1.assign(1, @console_window = ConsoleWindow.new(@textwm, self))
      @vsplits1.assign(2, setup_panel)

      @textwm.resize
      @textwm.focus_window(@console_window)

      @scheduler.logger = @log_window
    end

    def setup_panel
      panel = TextWM::Panel.new(@textwm)
      panel.add_button('h', 'Help') { HelpBrowser.new(@textwm).help_window }
      panel.add_button('p', 'PrevWin') { @textwm.focus_window(@textwm.prev_window) }
      panel.add_button('n', 'NextWin') { @textwm.focus_window(@textwm.next_window) }
      panel.add_button('c', 'CoreView') { toggle_core_view }
      panel.add_button('w', 'Warriors') { toggle_warriors_window }
      panel.add_button('r', 'Restart') { @console_window.restart }
      panel.add_button('b', 'Brkpt') { @console_window.toggle_breakpoint }
      panel.add_button('s', 'Step') { @console_window.step }
      panel.add_button('Return', 'Run') { @console_window.run }
      panel.add_button('Escape', nil) { @textwm.focus_window(@console_window) }

      panel
    end

    def load_warrior_into_core(warrior)
      unless (base_address = @memory_core.load_warrior(warrior))
        puts "Warrior '#{warrior.name}' could not be loaded into the core"
        return false
      end

      puts "Loaded '#{warrior.name}' into memory core at address #{aformat(base_address)}"

      # Tell the core window to show the code at the base address
      @core_window.show_address = base_address if @core_window

      warrior
    end

    def register_warrior(warrior)
      # This method may be called twice. That's not a mistake.
      return true if @warriors.include?(warrior)

      if @warriors.length >= MAX_WARRIORS
        puts "You can't use more than #{MAX_WARRIORS} warriors simultaneously"
        return false
      end

      @warriors << warrior

      true
    end

    def trace_execution(round)
      if (trace_file = @settings[:trace_file])
        @tracer = Tracer.new(0)
        old_debug_level = @debug_level
        self.debug_level = 1
      end

      yield

      return unless trace_file

      trace_file += round.zero? ? '' : "-#{round}"
      @tracer.save(trace_file)

      self.debug_level = old_debug_level
      @tracer = nil
    end

    def log_round_result(log, round)
      log.puts "Results of round #{round + 1}   Score Kills  Hits"

      # Sort warriors descending by their score
      warriors = @warriors.sort { |w1, w2| w2.score <=> w1.score }

      # If the first two have an identical score we call it a draw and don't
      # pick a winner.
      warriors.first.wins += 1 if warriors.length > 1 && warriors[0].score > warriors[1].score

      warriors.each_with_index do |warrior, index|
        log.puts "#{index + 1}. " \
          "#{format('%<name>-16s  %<score>5d %<kills>5d %<hits>5d',
                    name: warrior.name, score: warrior.score,
                    kills: warrior.kills, hits: warrior.hits)}"
      end
    end

    def log_match_result(log)
      # Sort warriors descending by their number of wins
      warriors = @warriors.sort { |w1, w2| w2.wins <=> w1.wins }

      log.puts 'Results of the battle   Wins'
      place = 0
      previous_wins = -1

      warriors.each do |warrior|
        place += 1 if previous_wins != warrior.wins
        log.puts "#{place}. #{format('%<name>-16s    %<wins>5d',
                                     name: warrior.name, wins: warrior.wins)}"
      end
    end
  end
end
