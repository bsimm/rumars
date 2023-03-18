# frozen_string_literal: true

module RuMARS
  # An operand of the Instruction. Could be the A or B operand.
  class Operand
    attr_reader :address_mode
    attr_accessor :number

    ADDRESS_MODES = %w[# $ @ * < { > }].freeze

    # @param address_mode [String] Address mode
    # @param number [String or Integer] Could be a label [String] that gets later relocated by the linker or an Integer number.
    def initialize(address_mode, number)
      raise ArgumentError, "Unknown addressing mode '#{address_mode}'" unless ADDRESS_MODES.include?(address_mode)

      @address_mode = address_mode
      @number = number
    end

    def evaluate(context)
      if @address_mode == '#' # Immedidate
        rp = wp = 0
      else
        # For instructions with a Direct mode, the Pointer
        # points to the instruction IR.Number away, relative to
        # the Program Counter.
        rp = @number
        wp = @number

        # For instructions with indirection in the A-operand
        # (Indirect, Pre-decrement, and Post-increment A-modes):

        if @address_mode != '$' # Not Direct
          # For instructions with Pre-decrement mode, the B-Field of the
          # instruction in Core currently pointed to by the Pointer is
          # decremented (M - 1 is added).
          if @address_mode == '<' # Pre-decrement
            ir = context.memory_core.load_relative(context.program_counter, wp)
            ir.b_number = (ir.b_number + context.memory_core.size - 1) % context.memory_core.size
          end

          # For instructions with Post-increment mode, the B-Field of the
          # instruction in Core currently pointed to by the Pointer will be
          # incremented.
          pii = context.memory_core.load_relative(context.program_counter, wp) if @address_mode == '>' # Post-increment

          # For instructions with indirection in the operand, the Pointer
          # ultimately points to the instruction Core[((PC + PCX) % M)].BNumber
          # away, relative to the instruction pointed to by Pointer.
          rp += context.memory_core.load_relative(context.program_counter, rp).b_number
          wp += context.memory_core.load_relative(context.program_counter, wp).b_number
        end
      end

      # The Instruction Register is a copy of the instruction pointed to by the Pointer.
      ir = context.memory_core.load_relative(context.program_counter, rp)

      # Execute the post-increment on the B-Number
      pii.b_number = (pii.b_number + 1) % context.memory_core.size if @address_mode == '>'

      [rp, wp, ir]
    end

    def pointer(context)
      context.program_counter + @number
    end

    def instruction(context)
      context.memory_core.load(pointer(context)).deep_copy
    end

    def value
      @number
    end

    def to_s
      "#{@address_mode}#{@number}"
    end

    def deep_copy
      Operand.new(@address_mode.clone, @number)
    end

    def ==(other)
      @address_mode == other.address_mode && @number == other.number
    end
  end
end
