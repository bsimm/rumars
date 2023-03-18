# frozen_string_literal: true

require_relative 'instruction'

module RuMARS
  # This class represents the core memory of the simulator. The size determines
  # how many instructions can be stored at most. When an instruction is
  # addressed, the address space wraps around so that the memory appears as a
  # circular space.
  class MemoryCore
    attr_reader :size

    def initialize(size = 8000)
      @size = size
      @instructions = []
      size.times do |address|
        @instructions[address] = Instruction.new(0, 'DAT', 'F', Operand.new('#', 0), Operand.new('#', 0))
      end
    end

    def load(address)
      raise ArgumentError, "address #{address} out of range" if address < -@size

      @instructions[(@size + address) % @size]
    end

    def store(address, instruction)
      raise ArgumentError, "address #{address} out of range" if address < -@size

      @instructions[(@size + address) % @size] = instruction
    end

    def load_relative(program_counter, address)
      instruction = load(program_counter + address)
      puts "Loading #{instruction} from #{program_counter + address}"
      instruction
    end

    def store_relative(program_counter, address, instruction)
      puts "Storing #{instruction} to #{program_counter + address}"
      store(program_counter + address, instruction)
    end

    def rel_to_abs_addr(program_counter, address)
      (program_counter + @size + address) % size
    end

    def dump
      (@size / 80).times do |line|
        80.times do |column|
          instruction = @instructions[(80 * line) + column]
          print instruction.pid
        end
        puts
      end
    end
  end
end
