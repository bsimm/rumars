# frozen_string_literal: true

require_relative 'operand'

module RuMARS
  OPCODES = %w[DAT MOV ADD SUB MUL DIV MOD JMP JMZ JMN DJN CMP SLT SPL].freeze
  MODIFIERS = %w[A B AB BA F X I].freeze

  ExecutionContext = Struct.new(:modifier, :program_counter, :memory_core, :pid, :base_address)

  # A REDCODE instruction that is stored in the core memory.
  class Instruction
    class DivBy0Error < RuntimeError
    end

    class InstructionBus
      attr_reader :memory_core, :base_address, :program_counter, :modifier, :pid
      attr_accessor :a_operand, :b_operand

      def initialize(memory_core, base_address, program_counter, modifier, pid)
        @memory_core = memory_core
        @base_address = base_address
        @program_counter = program_counter
        @modifier = modifier
        @pid = pid

        @a_operand = nil
        @b_operand = nil
      end
    end

    attr_accessor :pid, :opcode, :modifier, :a_operand, :b_operand, :address

    @debug_level = 0

    # Accessor for debug_level
    class << self
      attr_accessor :debug_level
    end

    # @param pid [Integer] PID of the Warrior this instruction belongs to. 0 means no owner.
    # @param opcode [String] Determines the type of instruction
    # @param modifier [String] Determines how the operands are used
    # @param a_operand [Operand] 'A' value of the instruction
    # @param b_operand [Operand] 'B' value of the instruction
    def initialize(pid, opcode, modifier, a_operand, b_operand)
      raise ArgumentError unless OPCODES.include?(opcode) || MODIFIERS.include?(modifier)

      # ID of the Warrior that either loaded or modified this instruction.
      @pid = pid
      # Address in the memory that the instruction is loaded to.
      @address = nil
      @opcode = opcode
      @modifier = modifier
      @a_operand = a_operand
      @b_operand = b_operand
    end

    def log(text)
      puts text if self.class.debug_level > 0
    end

    def log_update(text)
      puts "Updated #{text} of #{@address ? '%04d' % @address : 'XXXX'}: #{self}" if self.class.debug_level > 0
    end

    def a_number
      @a_operand&.number
    end

    def a_number=(number)
      @a_operand.number = number
      log_update('A-Number')
    end

    def decrement_a_number(core_size)
      @a_operand.number = (core_size + a_number - 1) % core_size
      log_update('A-Number')
    end

    def b_number
      @b_operand&.number
    end

    def b_number=(number)
      @b_operand.number = number
      log_update('B-Number')
    end

    def increment_b_number(core_size)
      @b_operand.number = (b_number + 1) % core_size
      log_update('B-Number')
    end

    def decrement_b_number(core_size)
      @b_operand.number = (core_size + b_number - 1) % core_size
      log_update('B-Number')
    end

    def evaluate_expressions(symbol_table, instruction_address)
      @a_operand.evaluate_expressions(symbol_table, instruction_address)
      @b_operand.evaluate_expressions(symbol_table, instruction_address)
    end

    def execute(memory_core, program_counter, pid, base_address)
      bus = InstructionBus.new(memory_core, base_address, program_counter, @modifier, pid)

      bus.a_operand = @a_operand.evaluate(bus)
      bus.b_operand = @b_operand.evaluate(bus)

      log("Executing #{"%04d" % @address} #{self}")
      next_pc = [program_counter + 1]

      case @opcode
      when 'ADD'
        arith('+', bus)
      when 'CMP'
        next_pc = cmp(bus)
      when 'DAT'
        next_pc = nil
      when 'DIV'
        begin
          arith('/', bus)
        rescue DivBy0Error
          next_pc = nil
        end
      when 'DJN'
        next_pc = djn(bus)
      when 'JMN'
        next_pc = jmn(bus)
      when 'JMP'
        next_pc = jmp(bus)
      when 'JMZ'
        next_pc = jmz(bus)
      when 'MOD'
        begin
          arith('%', bus)
        rescue DivBy0Error
          next_pc = nil
        end
      when 'MOV'
        mov(bus)
      when 'MUL'
        arith('*', bus)
      when 'SLT'
        next_pc = slt(bus)
      when 'SPL'
        next_pc = spl(bus)
      when 'SUB'
        arith('-', bus)
      else
        raise "Unknown opcode #{@opcode} at address #{program_counter}"
      end

      @a_operand.post_increment(bus, bus.a_operand)
      @b_operand.post_increment(bus, bus.b_operand)

      next_pc
    end

    # Create an identical deep copy.
    def deep_copy
      Instruction.new(@pid, @opcode.clone, @modifier.clone, @a_operand.deep_copy, @b_operand&.deep_copy)
    end

    def to_s
      "#{@opcode}.#{@modifier} #{@a_operand} #{@b_operand}"
    end

    def ==(other)
      @opcode == other.opcode && @modifier == other.modifier &&
        @a_operand == other.a_operand && @b_operand == other.b_operand
    end

    private

    def cmp(bus)
      ira = bus.a_operand.instruction
      irb = bus.b_operand.instruction

      next2_pc = [bus.program_counter + 2]

      case @modifier
      when 'A'
        return next2_pc if ira.a_number == irb.a_number
      when 'B'
        return next2_pc if ira.b_number == irb.b_number
      when 'AB'
        return next2_pc if ira.a_number == irb.b_number
      when 'BA'
        return next2_pc if ira.b_number == irb.a_number
      when 'F'
        return next2_pc if ira.a_number == irb.a_number && ira.b_number == irb.b_number
      when 'X'
        return next2_pc if ira.a_number == irb.b_number && ira.b_number == irb.a_number
      when 'I'
        return next2_pc if ira == irb
      else
        raise ArgumentError, "Unknown instruction modifier #{@modifier}"
      end

      [bus.program_counter + 1]
    end

    def arith(op, bus)
      ira = bus.a_operand.instruction
      irb = bus.b_operand.instruction

      core_size = bus.memory_core.size

      case @modifier
      when 'A'
        irb.a_number = arith_op(irb.a_number, op, ira.a_number, core_size)
      when 'B'
        irb.b_number = arith_op(irb.b_number, op, ira.b_number, core_size)
      when 'AB'
        irb.b_number = arith_op(ira.a_number, op, irb.b_number, core_size)
      when 'BA'
        irb.a_number = arith_op(ira.b_number, op, irb.a_number, core_size)
      when 'F', 'I'
        irb.a_number = arith_op(ira.a_number, op, irb.a_number, core_size)
        irb.b_number = arith_op(ira.b_number, op, irb.b_number, core_size)
      when 'X'
        irb.b_number = arith_op(ira.a_number, op, irb.b_number, core_size)
        irb.a_number = arith_op(ira.b_number, op, irb.a_number, core_size)
      else
        raise ArgumentError, "Unknown instruction modifier #{@modifier}"
      end
      irb.pid = bus.pid
    end

    def arith_op(op1, operator, op2, core_size)
      case operator
      when '+'
        log("Computing #{op1} + #{op2} = #{(op1 + op2) % core_size}")
        (op1 + op2) % core_size
      when '-'
        log("Computing #{op1} - #{op2} = #{(op1 - op2) % core_size}")
        (op1 + core_size - op2) % core_size
      when '*'
        log("Computing #{op1} * #{op2} = #{(op1 * op2) % core_size}")
        (op1 * op2) % core_size
      when '/'
        raise DivBy0Error if op2.zero?

        log("Computing #{op1} / #{op2} = #{op1 / op2}")
        op1 / op2
      when '%'
        raise DivBy0Error if op2.zero?

        log("Computing #{op1} % #{op2} = #{op1 % op2}")
        op1 % op2
      else
        raise ArgumentError, "Unknown operator #{operator}"
      end
    end

    def djn(bus)
      rpa = bus.a_operand.pointer
      ira = bus.a_operand.instruction
      irb = bus.b_operand.instruction

      core_size = bus.memory_core.size
      next_pc = [bus.program_counter + rpa]
      irb.pid = pid

      case @modifier
      when 'A', 'BA'
        irb.decrement_a_number(core_size)
        return next_pc unless irb.a_number.zero?
      when 'B', 'AB'
        irb.decrement_b_number(core_size)
        return next_pc unless irb.b_number.zero?
      when 'F', 'X', 'I'
        irb.decrement_a_number(core_size)
        irb.decrement_b_number(core_size)
        return next_pc if !ira.a_number.zero? || !irb.b_number.zero?
      else
        raise ArgumentError, "Unknown instruction modifier #{@modifier}"
      end

      [bus.program_counter + 1]
    end

    def jmp(bus)
      rpa = bus.a_operand.pointer

      # Return a PC-relative jump destination address
      [bus.memory_core.add_addresses(bus.program_counter, rpa)]
    end

    def jmz(bus)
      rpa = bus.a_operand.pointer
      irb = bus.b_operand.instruction

      # PC-relative jump destination address
      jump_pc = [bus.memory_core.add_addresses(bus.program_counter, rpa)]

      case @modifier
      when 'A', 'BA'
        return jump_pc if irb.a_number.zero?
      when 'B', 'AB'
        return jump_pc if irb.b_number.zero?
      when 'F', 'X', 'I'
        # Jump of both of the fields are zero
        return jump_pc if irb.a_number.zero? && irb.b_number.zero?
      else
        raise ArgumentError, "Unknown instruction modifier #{@modifier}"
      end

      [bus.program_counter + 1]
    end

    def jmn(bus)
      rpa = bus.a_operand.pointer
      irb = bus.b_operand.instruction

      jump_pc = [bus.memory_core.add_addresses(bus.program_counter, rpa)]

      case @modifier
      when 'A', 'BA'
        return jump_pc unless irb.a_number.zero?
      when 'B', 'AB'
        return jump_pc unless irb.b_number.zero?
      when 'F', 'X', 'I'
        # Jump if either of the fields are zero
        return jump_pc unless irb.a_number.zero? && irb.b_number.zero?
      else
        raise ArgumentError, "Unknown instruction modifier #{@modifier}"
      end

      [bus.program_counter + 1]
    end

    def mov(bus)
      ira = bus.a_operand.instruction
      wpb = bus.b_operand.pointer
      irb = bus.b_operand.instruction

      case @modifier
      when 'A'
        # Replaces A-number with A-number
        irb.a_number = ira.a_number
      when 'B'
        # Replaces B-number with B-number
        irb.b_number = ira.b_number
      when 'AB'
        # Replaces B-number with A-number
        irb.b_number = ira.a_number
      when 'BA'
        # Replaces A-number with B-number
        irb.a_number = ira.b_number
      when 'F'
        # Replaces A-number with A-number and B-number with B-number
        irb.a_number = ira.a_number
        irb.b_number = ira.b_number
      when 'X'
        # Replaces B-number with A-number and A-number with B-number
        irb.a_number = ira.b_number
        irb.b_number = ira.a_number
      when 'I'
        # Copies entire instruction
        bus.memory_core.store_relative(bus.base_address, bus.program_counter, wpb, ira).deep_copy
      else
        raise ArgumentError, "Unknown instruction modifier #{@modifier}"
      end

      # Ensure ownership of modified instruction
      irb.pid = bus.pid
    end

    def slt(bus)
      ira = bus.a_operand.instruction
      irb = bus.b_operand.instruction

      jump_pc = [bus.program_counter + 2]

      case @modifier
      when 'A'
        return jump_pc if ira.a_number < irb.a_number
      when 'B'
        return jump_pc if ira.b_number < irb.b_number
      when 'AB'
        return jump_pc if ira.a_number < irb.b_number
      when 'BA'
        return jump_pc if ira.b_number < irb.a_number
      when 'F', 'I'
        return jump_pc if ira.a_number < irb.a_number && ira.b_number < irb.b_number
      when 'X'
        return jump_pc if ira.a_number < irb.b_number && ira.b_number < irb.a_number
      else
        raise ArgumentError, "Unknown instruction modifier #{@modifier}"
      end

      [bus.program_counter + 1]
    end

    def spl(bus)
      rpa = bus.a_operand.pointer

      # Fork off another thread. One thread continues at the next instruction, the other at
      # the A-Pointer.
      [bus.program_counter + 1, bus.memory_core.add_addresses(bus.program_counter, rpa)]
    end
  end
end
