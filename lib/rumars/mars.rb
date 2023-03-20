# frozen_string_literal: true

require_relative 'memory_core'
require_relative 'scheduler'
require_relative 'warrior'

module RuMARS
  # Memory Array Redcode Simulator
  # https://vyznev.net/corewar/guide.html
  # http://www.koth.org/info/icws94.html
  class MARS
    def initialize(argv)
      @memory_core = MemoryCore.new(800)
      @scheduler = Scheduler.new(@memory_core)
      # Certain commands like 'list' focus on a certain warrior. By default,
      # it is the more recently loaded warrior. Use the 'focus' command to
      # change the current warrior.
      @current_warrior = nil

      # Load all the Redcode files passed via the command line.
      argv.each do |file|
        load_warrior(file) if file[0] != '-' && file[-4..] == '.red'
      end
    end

    def add_warrior(warrior, base_address = 0)
      @scheduler.add_warrior(warrior, base_address)
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

    private

    def execute(command)
      args = command.split(/\s+/)

      case args.shift
      when 'dump', 'du'
        @memory_core.dump
      when 'exit', 'ex'
        return false
      when 'focus', 'fo'
        change_current_warrior(args.first&.to_i)
      when 'list', 'li'
        @memory_core.list(@scheduler.program_counters, @current_warrior,
                          *args.map(&:to_i))
      when 'load', 'lo'
        load_warriors(args)
      when 'step', 'st'
        @scheduler.step
      when 'run', 'ru'
        @scheduler.run(args.first&.to_i || -1)
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

    def change_current_warrior(index)
      unless (warrior = @scheduler.get_warrior_by_index(index))
        puts "Unknown warrior #{index}"
      end

      @current_warrior = warrior
    end
  end
end
