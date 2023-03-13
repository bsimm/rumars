# frozen_string_literal: true

require_relative 'instruction'

module RuMARS
  # This class represents the core memory of the simulator. The size determines
  # how many instructions can be stored at most. When an instruction is
  # addressed, the address space wraps around so that the memory appears as a
  # circular space.
  class MemoryCore
    def initialize(size = 8000)
      @instructions = []
      size.times do |address|
        @instructions[address] = Instruction.new(0, 'DAT', 'F', Operand.new('#', 0), Operand.new('#', 0))
      end
    end

    def size
      @instructions.size
    end

    def load(address)
      @instructions[address % size]
    end

    def store(address, instruction)
      @instructions[address % size] = instruction
    end
  end
end
