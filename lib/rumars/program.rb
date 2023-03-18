# frozen_string_literal: true

module RuMARS
  # Intermediate representation of a REDCODE program as returned by the Parser.
  class Program
    def initialize
      @instructions = []
    end

    def append_instruction(instruction)
      @instructions << instruction
    end

    def load(start_address, memory_core, pid)
      address = start_address
      @instructions.each do |instruction|
        instruction_copy = instruction.deep_copy
        instruction_copy.pid = pid
        memory_core.store(address, instruction_copy)
        address += 1
      end
    end
  end
end
