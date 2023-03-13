# frozen_string_literal: true

require_relative 'warrior'
require_relative 'memory_core'

module RuMARS
  # The scheduler manages the task queues of the warriors.
  class Scheduler
    def initialize(memory_core)
      @memory_core = memory_core
      @warriors = []
    end

    def add_warrior(warrior)
      raise ArgumentError, 'Warrior is already known' if @warriors.include?(warrior)

      @warriors << warrior
      # Set the PID for the warrior
      warrior.pid = @warriors.length
      warrior.load_program(0, @memory_core)
    end

    def run(max_cycles = -1)
      loop do
        @warriors.each do |warrior|
          next unless warrior.alive?

          address = warrior.next_task
          instruction = @memory_core.load(address)
          pics = instruction.execute(@memory_core, address)
          # Append the next instruction address(es) to the task queue of the warrior.
          warrior.append_tasks(pics) if pics
        end

        break if all_warriors_dead? || (max_cycles -= 1).zero?
      end
    end

    private

    # All warriors are dead if their task queues are all empty.
    def all_warriors_dead?
      @warriors.each do |warrior|
        return false if warrior.alive?
      end

      true
    end
  end
end
