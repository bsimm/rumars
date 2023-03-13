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
      @memory_core = MemoryCore.new(8)
      @scheduler = Scheduler.new(@memory_core)
      @cycles = 800
    end

    def add_warrior(warrior)
      @scheduler.add_warrior(warrior)
    end

    def run
      @scheduler.run(@cycles)
    end
  end
end
