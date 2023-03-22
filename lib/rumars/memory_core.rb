# frozen_string_literal: true

require 'rainbow'

require_relative 'instruction'

module RuMARS
  # This class represents the core memory of the simulator. The size determines
  # how many instructions can be stored at most. When an instruction is
  # addressed, the address space wraps around so that the memory appears as a
  # circular space.
  class MemoryCore
    attr_reader :size
    attr_accessor :debug_level

    COLORS = %i[silver red green yellow blue magenta cyan aqua indianred]

    def initialize(size = 8000)
      @size = size
      @instructions = []
      @debug_level = 0
      size.times do |address|
        store(address, Instruction.new(0, 'DAT', 'F', Operand.new('#', 0), Operand.new('#', 0)))
      end
    end

    def log(text)
      puts text if @debug_level > 0
    end

    def load(address)
      raise ArgumentError, "address #{address} out of range" if address < -@size

      @instructions[(@size + address) % @size]
    end

    def store(address, instruction)
      raise ArgumentError, "address #{address} out of range" if address < -@size

      core_address = (@size + address) % @size
      instruction.address = core_address
      @instructions[core_address] = instruction
    end

    def list(program_counters, current_warrior, start_address = current_warrior.base_address, length = 10)
      length.times do |i|
        address = start_address + i
        puts" #{'%04d' % address} #{program_counters.include?(address) ? '>' : ' '} #{'%-8s' % current_warrior.resolve_address(address)} #{@instructions[address]}"
      end
    end

    def load_relative(base_address, program_counter, address)
      core_address = (@size + base_address + program_counter + address) % @size
      instruction = load(core_address)
      log("Loading #{'%04d' % core_address}: #{instruction}")
      instruction
    end

    def store_relative(base_address, program_counter, address, instruction)
      core_address = (@size + base_address + program_counter + address) % @size
      log("Storing #{'%04d' % core_address}: #{instruction}")
      store(core_address, instruction)
    end

    def add_addresses(program_counter, address)
      (program_counter + @size + address) % size
    end

    def dump(program_counters)
      term = Rainbow.new

      (@size / 80).times do |line|
        80.times do |column|
          address = (80 * line) + column
          instruction = @instructions[address]
          print term.wrap(instruction_character(instruction)).color(COLORS[instruction.pid])
                    .background(program_counters.include?(address) ? :white : :black)
        end
        puts
      end
    end

    def instruction_character(instruction)
      case instruction.opcode
      when 'DAT'
        'X'
      when 'ADD'
        '+'
      when 'SUB'
        '-'
      when 'MUL'
        '*'
      when 'DIV'
        '/'
      when 'MOD'
        '%'
      when 'MOV'
        'M'
      when 'JMP', 'JMZ', 'JMN', 'DJN', 'CMP', 'SLT'
        'J'
      when 'SPL'
        '<'
      else
        '?'
      end
    end
  end
end
