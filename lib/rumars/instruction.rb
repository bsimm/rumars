# frozen_string_literal: true

require_relative 'operand'

module RuMARS
  OPCODES = %w[DAT MOV ADD SUB MUL DIV MOD JMP JMZ JMN DJN CMP SLT SPL].freeze
  MODIFIERS = %w[A B AB BA F X I].freeze

  # A REDCODE instruction that is stored in the core memory.
  class Instruction
    attr_accessor :pid

    # @param pid [Integer] PID of the Warrior this instruction belongs to. 0 means no owner.
    # @param opcode [String] Determines the type of instruction
    # @param modifier [String] Determines how the operands are used
    # @param a_value [Operand] 'A' value of the instruction
    # @param b_value [Operand] 'B' value of the instruction
    def initialize(pid, opcode, modifier, a_value, b_value)
      raise ArgumentError unless OPCODES.include?(opcode) || MODIFIERS.include?(modifier)

      @pid = pid
      @opcode = opcode
      @modifier = modifier
      @a_value = a_value
      @b_value = b_value
    end

    def execute(memory_core, my_address)
      puts "Executing #{"%04X" % my_address} #{self}"
      case @opcode
      when 'DAT'
        return nil
      when 'MOV'
        memory_core.store(my_address + @b_value.value, memory_core.load(my_address + @a_value.value).deep_copy)
      else
        raise "Unknown opcode #{@opcode} at address #{my_address}"
      end

      [ my_address + 1 ]
    end

    # Create an identical deep copy.
    def deep_copy
      Instruction.new(@pid, @opcode.clone, @modifier.clone, @a_value.deep_copy, @b_value.deep_copy)
    end

    def to_s
      "#{@opcode}.#{@modifier} #{@a_value} #{@b_value}"
    end
  end
end
