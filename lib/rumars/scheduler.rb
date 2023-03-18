# frozen_string_literal: true

require_relative 'warrior'
require_relative 'memory_core'

module RuMARS
  # The scheduler manages the task queues of the warriors.
  class Scheduler
    attr_reader :cycles

    def initialize(memory_core)
      @memory_core = memory_core
      @warriors = []
    end

    def add_warrior(warrior, start_address)
      raise ArgumentError, 'Warrior is already known' if @warriors.include?(warrior)

      @warriors << warrior
      # Set the PID for the warrior
      warrior.pid = @warriors.length
      warrior.load_program(0, @memory_core)
      warrior.start_address = start_address
    end

    def warrior_count
      @warriors.size
    end

    def run(max_cycles = -1)
      @cycles = 0
      loop do
        step

        @cycles += 1
        break if all_warriors_dead? || (max_cycles > 0 && @cycles >= max_cycles)
      end
    end

    # Execute one step for each Warrior
    def step
      @warriors.each do |warrior|
        # Skip dead Warriors
        next unless warrior.alive?

        # Pull next PC from task queue
        address = warrior.next_task
        # Load instruction
        instruction = @memory_core.load(address)
        # and execute it
        next unless (pics = instruction.execute(@memory_core, address))

        # Ensure that all pushed program counters are within the core memory
        pics.map! { |pc| pc % @memory_core.size }
        # Append the next instruction address(es) to the task queue of the warrior.
        warrior.append_tasks(pics)
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
