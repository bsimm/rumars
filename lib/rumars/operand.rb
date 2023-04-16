# frozen_string_literal: true

require_relative 'expression'
require_relative 'memory_core'

module RuMARS
  # An operand of the Instruction. Could be the A or B operand.
  class Operand
    attr_reader :address_mode
    attr_accessor :number

    ADDRESS_MODES = ['', '#', '$', '@', '*', '<', '{', '>', '}'].freeze

    class OperandBus
      attr_accessor :pointer, :instruction, :post_incr_instr

      def initialize
        @pointer = @instruction = @post_incr_instr = nil
      end

      def to_s
        "pointer: #{@pointer}  instruction: #{@instruction}  post_inc_inst: #{@post_incr_instr}"
      end
    end

    # @param address_mode [String] Address mode
    # @param number [String or Integer] Could be a label [String] that gets later relocated by the linker or an Integer number.
    def initialize(address_mode, number)
      raise ArgumentError, "Unknown addressing mode '#{address_mode}'" unless ADDRESS_MODES.include?(address_mode)

      @address_mode = address_mode
      @number = number
    end

    def evaluate_expressions(symbol_table, instruction_address)
      @number = MemoryCore.fold(@number.eval(symbol_table, instruction_address))
    end

    def evaluate(bus)
      base_address = bus.base_address
      program_counter = bus.program_counter
      memory_core = bus.memory_core

      op_bus = OperandBus.new

      if @address_mode == '#' || @address_mode == '' # Immedidate
        # The pointer is set to 0 for immediate values.
        op_bus.pointer = 0
      else
        op_bus.pointer = @number

        if @address_mode != '$' # Not Direct
          # For indirect modes @*<>{} the number points to another instruction
          # who's A- or B-numbers will be used to select the final instruction.
          direct_instr = memory_core.load_relative(base_address, program_counter,
                                                   op_bus.pointer, bus.pid)
          op_bus.pointer +=
            if '<{'.include?(@address_mode) # Pre-decrement
              # Take ownership of the modified instruction
              if @address_mode == '<'
                direct_instr.decrement_b_number(bus.pid)
              else
                direct_instr.decrement_a_number(bus.pid)
              end
            else
              # Add A- or B-number to the pointer for '*', '}', '@' or '>' addressing modes.
              '@>'.include?(@address_mode) ? direct_instr.b_number : direct_instr.a_number
            end
          op_bus.pointer = MemoryCore.fold(op_bus.pointer)
        end
      end

      # Load the instruction that is addressed by this operand.
      op_bus.instruction = bus.memory_core.load_relative(base_address, program_counter,
                                                         op_bus.pointer, bus.pid)
      op_bus.post_incr_instr = direct_instr if '>}'.include?(@address_mode)

      op_bus
    end

    def post_increment(bus, op_bus)
      return unless (instruction = op_bus.post_incr_instr)

      # Execute the post-increment on the A- or B-Number of the instruction
      # pointed to by pii
      if @address_mode == '>'
        instruction.increment_b_number(bus.pid)
      else # '}'
        instruction.increment_a_number(bus.pid)
      end
    end

    def to_s
      first_negative = MemoryCore.size / 2
      "#{@address_mode}#{@number >= first_negative ? -(MemoryCore.size - @number) : @number}"
    end

    def deep_copy
      Operand.new(@address_mode.clone, @number)
    end

    def ==(other)
      @address_mode == other.address_mode && @number == other.number
    end
  end
end
