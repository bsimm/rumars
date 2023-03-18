# frozen_string_literal: true

require_relative 'memory_core'
require_relative 'scheduler'
require_relative 'warrior'

module RuMARS
  # Memory Array Redcode Simulator
  # https://vyznev.net/corewar/guide.html
  # http://www.koth.org/info/icws94.html
  class MARS
    def initialize
      @memory_core = MemoryCore.new(800)
      @scheduler = Scheduler.new(@memory_core)
    end

    def add_warrior(warrior, start_address = 0)
      @scheduler.add_warrior(warrior, start_address)
    end

    def run(max_cycles = 800)
      @scheduler.run(max_cycles)
    end

    def repl
      loop do
        print 'MARS>> '
        command = gets.chomp

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
        warrior = Warrior.new("Player #{@scheduler.warrior_count}")
        warrior.parse_file(file)
        @scheduler.add_warrior(warrior, 1)
      end
    end
  end
end
