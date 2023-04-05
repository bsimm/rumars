# frozen_string_literal: true

require 'rainbow'

require_relative 'instruction'

module RuMARS
  # This class represents the core memory of the simulator. The size determines
  # how many instructions can be stored at most. When an instruction is
  # addressed, the address space wraps around so that the memory appears as a
  # circular space.
  class MemoryCore
    attr_accessor :tracer

    COLORS = %i[silver red green yellow blue magenta cyan aqua indianred]

    @size = 8000

    # Accessor for size
    class << self
      attr_accessor :size
    end

    def initialize(settings)
      @settings = settings
      MemoryCore.size = @settings[:core_size]
      @instructions = []
      @warriors = []
      @tracer = nil
      MemoryCore.size.times do |address|
        poke(address, Instruction.new(0, 'DAT', 'F', Operand.new('', 0), Operand.new('', 0)))
      end
    end

    def self.fold(address)
      (MemoryCore.size + address) % MemoryCore.size
    end

    def load_warrior(warrior)
      # Make sure the warrior has a valid program
      return nil unless warrior.program

      return nil unless (base_address = find_base_address(warrior.size))

      @warriors << warrior

      address = base_address
      # The program ID is the index in the loaded warrior list (+1).
      pid = @warriors.length
      warrior.program.instructions.each do |instruction|
        instruction_copy = instruction.deep_copy
        instruction_copy.address = address
        instruction_copy.pid = pid
        poke(address, instruction_copy)

        address = MemoryCore.fold(address + 1)
      end
      warrior.restart(base_address, pid)

      base_address
    end

    def peek(address)
      raise ArgumentError, "address #{address} out of range" if address.negative? || address >= MemoryCore.size

      @instructions[address]
    end

    def poke(address, instruction)
      raise ArgumentError, "address #{address} out of range" if address.negative? || address >= MemoryCore.size

      instruction.address = address
      @instructions[address] = instruction
    end

    def load_relative(base_address, program_counter, address)
      core_address = MemoryCore.fold(base_address + program_counter + address)
      instruction = peek(core_address)
      @tracer&.log_load(core_address, instruction.to_s)
      instruction
    end

    def store_relative(base_address, program_counter, address, instruction)
      core_address = MemoryCore.fold(base_address + program_counter + address)
      @tracer&.log_store(core_address, instruction.to_s)
      poke(core_address, instruction)
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
        # Ignore warriors that have not been loaded yet
        next unless warrior.base_address

        warrior_zone_start = warrior.base_address - @settings.min_distance
        warrior_zone_end = warrior.base_address + warrior.size + @settings.min_distance

        if (start_address >= warrior_zone_start && start_address <= warrior_zone_end) ||
           (end_address >= warrior_zone_start && end_address <= warrior_zone_end)
          return true
        end
      end

      false
    end
  end
end
