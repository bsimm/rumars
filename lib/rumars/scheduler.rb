# frozen_string_literal: true

require_relative 'warrior'
require_relative 'memory_core'

module RuMARS
  # The scheduler manages the task queues of the warriors.
  class Scheduler
    attr_reader :cycles
    attr_accessor :debug_level

    def initialize(memory_core)
      @memory_core = memory_core
      @warriors = []
      @breakpoints = []
      @debug_level = 0
      @min_distance = MemoryCore.size / 16
    end

    def log(text)
      puts text if @debug_level > 0
    end

    def add_warrior(warrior)
      raise ArgumentError, 'Warrior is already known' if @warriors.include?(warrior)

      unless (base_address = find_base_address(warrior.size))
        puts 'No more space in core memory to load another warrior'
      end

      @warriors << warrior
      # Set the PID for the warrior
      warrior.pid = @warriors.length

      warrior.load_program(base_address, @memory_core)
    end

    def get_warrior_by_index(index)
      @warriors[index]
    end

    def warrior_count
      @warriors.size
    end

    def run(max_cycles = -1)
      @cycles = 0
      loop do
        step

        @cycles += 1
        # Stop if the maximum cycle number has been reached or
        # all warriors have died.
        break if alive_warriors.zero? || (max_cycles.positive? && @cycles >= max_cycles)

        if @breakpoints.intersect?(program_counters)
          puts "Hit breakpoint at #{@breakpoints & program_counters} after #{@cycles} cycles"
          break
        end
      end
    end

    # Run until only a single warrior is still alive
    def battle(rounds = 7, max_cycles = -1)
      rounds.times do |round|
        @cycles = 0
        loop do
          step

          @cycles += 1
          break if alive_warriors == 1

          if max_cycles > 0 && @cycles >= max_cycles
            puts "No winner was found after #{max_cycles} cycles"
            break
          end
        end
      end
    end

    # Execute one step for each Warrior
    def step
      @warriors.each do |warrior|
        # Skip dead Warriors
        next unless warrior.alive?

        log("PCs: #{program_counters}")
        # Pull next PC from task queue
        address = warrior.next_task
        # Load instruction
        instruction = @memory_core.load(MemoryCore.fold(address + warrior.base_address))
        # and execute it
        log("Executing instruction #{'%04d' % address}: #{instruction}")
        unless (pics = instruction.execute(@memory_core, address, warrior.pid, warrior.base_address))
          puts "*** Warrior #{warrior.name} has died in cycle #{@cycles} ***" if warrior.task_queue.empty?
          next
        end

        # Ensure that all pushed program counters are within the core memory
        pics.map! { |pc| MemoryCore.fold(pc) }
        # Append the next instruction address(es) to the task queue of the warrior.
        warrior.append_tasks(pics)

        if pics.length > 1
          log("New thread started at #{pics[1]}")
        end

        if (next_pc = warrior.task_queue.last) != MemoryCore.fold(address + 1)
          log("Jumped to #{'%04d' % next_pc}: #{@memory_core.load(next_pc)}")
        end
      end
    end

    # @return [Array of Integer] List of absolute program counters for all warriors.
    def program_counters(warrior = nil)
      return warrior.task_queue.map { |pc| MemoryCore.fold(pc + warrior.base_address) } if warrior

      pcs = []

      @warriors.each do |warrior|
        # Get list of relative PCs from warriors and convert them into absolute PCs.
        pcs += warrior.task_queue.map { |pc| MemoryCore.fold(pc + warrior.base_address) }
      end

      pcs
    end

    def add_breakpoint(address)
      @breakpoints << address unless @breakpoints.include?(address)
    end

    def delete_breakpoint(address)
      @breakpoints.delete(address)
    end

    private

    # All warriors are dead if their task queues are all empty.
    def all_warriors_dead?
      @warriors.each do |warrior|
        return false if warrior.alive?
      end

      true
    end

    def alive_warriors
      alive = 0
      @warriors.each do |warrior|
        alive += 1 if warrior.alive?
      end

      alive
    end

    def find_base_address(size)
      # The first warrior is always loaded to absolute address 0.
      return 0 if @warriors.empty?

      i = 0
      loop do
        address = rand(MemoryCore.size)

        return address unless too_close_to_other_warriors?(address, address + size)

        if (i += 1) > 1000
          return nil
        end
      end
    end

    def too_close_to_other_warriors?(start_address, end_address)
      # All warriors must fit into the core without wrapping around.
      return true if end_address >= MemoryCore.size

      @warriors.each do |warrior|
        warrior_zone_start = warrior.base_address - @min_distance
        warrior_zone_end = warrior.base_address + warrior.size + @min_distance

        if (start_address >= warrior_zone_start && start_address <= warrior_zone_end) ||
           (end_address >= warrior_zone_start && end_address <= warrior_zone_end)
          return true
        end
      end

      false
    end
  end
end
