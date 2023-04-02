# frozen_string_literal: true

require_relative 'warrior'
require_relative 'memory_core'

module RuMARS
  # The scheduler manages the task queues of the warriors.
  class Scheduler
    attr_reader :cycles, :breakpoints
    attr_accessor :debug_level, :tracer, :logger

    def initialize(memory_core, min_distance)
      @memory_core = memory_core
      @min_distance = min_distance
      @warriors = []
      @breakpoints = []
      @debug_level = 0
      @logger = $stdout
      @tracer = nil
      @cycle_counter = 0
    end

    def log(text)
      @logger.puts text
    end

    def add_warrior(warrior)
      raise ArgumentError, 'Warrior is already known' if @warriors.include?(warrior)

      unless (base_address = find_base_address(warrior.size))
        log('No more space in core memory to load another warrior')
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
      cycles = 0
      loop do
        step

        cycles += 1
        # Stop if the maximum cycle number has been reached or
        # all warriors have died.
        break if alive_warriors.zero? || (max_cycles.positive? && cycles >= max_cycles)

        if @breakpoints.intersect?(program_counters)
          log("Hit breakpoint at #{@breakpoints & program_counters} after #{cycles} cycles")
          break
        end
      end
    end

    # Run until only a single warrior is still alive
    def battle(max_cycles = -1)
      cycles = 0
      # Clear screen
      print("\ec")
      loop do
        # Move cursor back to top left corner
        print("\e[0;0H")
        step
        @memory_core.dump(program_counters)

        cycles += 1
        break if alive_warriors == 1

        if max_cycles.positive? && cycles >= max_cycles
          log("No winner was found after #{max_cycles} cycles")
          break
        end
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
        core_address = MemoryCore.fold(address + warrior.base_address)
        instruction = @memory_core.load(core_address)
        @tracer&.next_instruction(core_address, instruction.to_s)
        @tracer&.cycle(@cycle_counter)

        # and execute it
        @cycle_counter += 1
        unless (pics = instruction.execute(@memory_core, address, warrior.pid, warrior.base_address))
          if warrior.task_queue.empty?
            log("*** Warrior #{warrior.name} has died in cycle #{@cycle_counter} ***")
          else
            log("* Warrior #{warrior.name} thread of #{warrior.task_queue.length} ended *")
          end
          @tracer&.program_counters(warrior.task_queue)
          next
        end

        # Ensure that all pushed program counters are within the core memory
        pics.map! { |pc| MemoryCore.fold(pc) }
        # Append the next instruction address(es) to the task queue of the warrior.
        warrior.append_tasks(pics)

        log("New thread started at #{pics[1]}") if pics.length > 1

        @tracer&.program_counters(warrior.task_queue)
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

    def toggle_breakpoint(address)
      if @breakpoints.include?(address)
        @breakpoints.delete(address)
      else
        @breakpoints << address
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
