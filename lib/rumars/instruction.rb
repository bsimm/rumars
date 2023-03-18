# frozen_string_literal: true

require_relative 'operand'

module RuMARS
  OPCODES = %w[DAT MOV ADD SUB MUL DIV MOD JMP JMZ JMN DJN CMP SLT SPL].freeze
  MODIFIERS = %w[A B AB BA F X I].freeze

  ExecutionContext = Struct.new(:modifier, :program_counter, :memory_core)

  # A REDCODE instruction that is stored in the core memory.
  class Instruction
    class DivBy0Error < RuntimeError
    end

    attr_accessor :pid, :opcode, :modifier, :a_operand, :b_operand

    # @param pid [Integer] PID of the Warrior this instruction belongs to. 0 means no owner.
    # @param opcode [String] Determines the type of instruction
    # @param modifier [String] Determines how the operands are used
    # @param a_operand [Operand] 'A' value of the instruction
    # @param b_operand [Operand] 'B' value of the instruction
    def initialize(pid, opcode, modifier, a_operand, b_operand)
      raise ArgumentError unless OPCODES.include?(opcode) || MODIFIERS.include?(modifier)

      @pid = pid
      @opcode = opcode
      @modifier = modifier
      @a_operand = a_operand
      @b_operand = b_operand
    end

    def a_number
      @a_operand&.number
    end

    def a_number=(number)
      @a_operand.number = number
    end

    def b_number
      @b_operand&.number
    end

    def b_number=(number)
      @b_operand.number = number
    end

    def execute(memory_core, program_counter)
      context = ExecutionContext.new(@modifier, program_counter, memory_core)

      puts "Executing #{"%04X" % program_counter} #{self}"
      case @opcode
      when 'ADD'
        arith('+', context)
      when 'CMP'
        return cmp(context)
      when 'DAT'
        return nil
      when 'DIV'
        begin
          arith('/', context)
        rescue DivBy0Error
          return nil
        end
      when 'DJN'
        return djn(context)
      when 'JMN'
        return jmn(context)
      when 'JMP'
        return jmp(context)
      when 'JMZ'
        return jmz(context)
      when 'MOD'
        begin
          arith('%', context)
        rescue DivBy0Error
          return nil
        end
      when 'MOV'
        mov(context)
      when 'MUL'
        arith('*', context)
      when 'SLT'
        slt(context)
      when 'SPL'
        return spl(context)
      when 'SUB'
        arith('-', context)
      else
        raise "Unknown opcode #{@opcode} at address #{program_counter}"
      end

      [program_counter + 1]
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

    def cmp(context)
      ira = @a_operand.evaluate(context)[2]
      irb = @b_operand.evaluate(context)[2]

      next2_pc = [context.program_counter + 2]

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

      [context.program_counter + 1]
    end

    def arith(op, context)
      _, _, ira = @a_operand.evaluate(context)
      _, wpb, irb = @b_operand.evaluate(context)

      wpb_instruction = context.memory_core.load_relative(context.program_counter, wpb)

      case @modifier
      when 'A'
        wpb_instruction.a_number = arith_op(irb.a_number, op, ira.a_number, context)
      when 'B'
        wpb_instruction.b_number = arith_op(irb.b_number, op, ira.b_number, context)
      when 'AB'
        wpb_instruction.b_number = arith_op(ira.a_number, op, irb.b_number, context)
      when 'BA'
        wpb_instruction.a_number = arith_op(ira.b_number, op, irb.a_number, context)
      when 'F', 'I'
        wpb_instruction.a_number = arith_op(ira.a_number, op, irb.a_number, context)
        wpb_instruction.b_number = arith_op(ira.b_number, op, irb.b_number, context)
      when 'X'
        wpb_instruction.b_number = arith_op(ira.a_number, op, irb.b_number, context)
        wpb_instruction.a_number = arith_op(ira.b_number, op, irb.a_number, context)
      else
        raise ArgumentError, "Unknown instruction modifier #{@modifier}"
      end
    end

    def arith_op(op1, operator, op2, context)
      case operator
      when '+'
        res = (op1 + op2) % context.memory_core.size
        puts "#{op1} + #{op2} = #{res}"
        res
      when '-'
        (op1 + context.memory_core.size - op2) % context.memory_core.size
      when '*'
        (op1 * op2) % context.memory_core.size
      when '/'
        raise DivBy0Error if op2.zero?

        op1 / op2
      when '%'
        raise DivBy0Error if op2.zero?

        op1 % op2
      else
        raise ArgumentError, "Unknown operator #{operator}"
      end
    end

    def dnj(context)
      rpa, _, ira = @a_operand.evaluate(context)
      _, wpb, irb = @b_operand.evaluate(context)

      next_pc = context.program_counter + rpa
      wpb_instruction = context.memory_core.load_relative(context.program_counter, wpb)
      case @modifier
      when 'A', 'BA'
        wpb_instruction.a_number = (memory_core.size + wpb_instruction.a_number - 1) % memory_core.size
        irb.a_number -= 1
        return next_pc unless irb.a_number.zero?
      when 'B', 'AB'
        wpb_instruction.b_number = (memory_core.size + wpb_instruction.b_number - 1) % memory_core.size
        irb.b_number -= 1
        return next_pc unless irb.b_number.zero?
      when 'F', 'X', 'I'
        wpb_instruction.a_number = (memory_core.size + wpb_instruction.a_number - 1) % memory_core.size
        wpb_instruction.b_number = (memory_core.size + wpb_instruction.b_number - 1) % memory_core.size
        irb.b_number -= 1
        return next_pc if !ira.a_number.zero? || !irb.b_number.zero?
      else
        raise ArgumentError, "Unknown instruction modifier #{@modifier}"
      end

      [context.program_counter + 1]
    end

    def jmp(context)
      rpa = @a_operand.evaluate(context)&.first
      [context.memory_core.rel_to_abs_addr(context.program_counter, rpa)]
    end

    def jmz(context)
      rpa = @a_operand.evaluate(context).first
      irb = @b_operand.evaluate(context)[2]

      case @modifier
      when 'A', 'BA'
        return [context.memory_core.rel_to_abs_addr(context.program_counter, rpa)] if irb.a_number.zero?
      when 'B', 'AB'
        return [context.memory_core.rel_to_abs_addr(context.program_counter, rpa)] if irb.b_number.zero?
      when 'F', 'X', 'I'
        return [context.memory_core.rel_to_abs_addr(context.program_counter, rpa)] if irb.a_number.zero? && irb.b_number.zero?
      else
        raise ArgumentError, "Unknown instruction modifier #{@modifier}"
      end

      [context.program_counter + 1]
    end

    def jmn(context)
      rpa = @a_operand.evaluate(context).first
      irb = @b_operand.evaluate(context)[2]

      new_pc = [context.memory_core.rel_to_abs_addr(context.program_counter, rpa)]
      case @modifier
      when 'A', 'BA'
        return new_pc unless irb.a_number.zero?
      when 'B', 'AB'
        return new_pc unless irb.b_number.zero?
      when 'F', 'X', 'I'
        return new_pc unless irb.a_number.zero? && irb.b_number.zero?
      else
        raise ArgumentError, "Unknown instruction modifier #{@modifier}"
      end

      [context.program_counter + 1]
    end

    def mov(context)
      _, _, ira = @a_operand.evaluate(context)
      _, wpb = @b_operand.evaluate(context)

      case @modifier
      when 'A'
        # Replaces A-number with A-number
        context.memory_core.load_relative(context.program_counter, wpb).a_number = ira.a_number
      when 'B'
        # Replaces B-number with B-number
        context.memory_core.load_relative(context.program_counter, wpb).b_number = ira.b_number
      when 'AB'
        # Replaces B-number with A-number
        context.memory_core.load_relative(context.program_counter, wpb).b_number = ira.a_number
      when 'BA'
        # Replaces A-number with B-number
        context.memory_core.load_relative(context.program_counter, wpb).a_number = ira.b_number
      when 'F'
        # Replaces A-number with A-number and B-number with B-number
        context.memory_core.load_relative(context.program_counter, wpb).a_number = ira.a_number
        context.memory_core.load_relative(context.program_counter, wpb).b_number = ira.b_number
      when 'X'
        # Replaces B-number with A-number and A-number with B-number
        context.memory_core.load_relative(context.program_counter, wpb).a_number = ira.b_number
        context.memory_core.load_relative(context.program_counter, wpb).b_number = ira.a_number
      when 'I'
        # Copies entire instruction
        context.memory_core.store_relative(context.program_counter, wpb, ira.deep_copy)
      else
        raise ArgumentError, "Unknown instruction modifier #{@modifier}"
      end
    end

    def slt(context)
      ira = @a_operand.evaluate(context)[2]
      irb = @b_operand.evaluate(context)[2]

      next2_pc = [context.program_counter + 2]
      case @modifier
      when 'A'
        return next2_pc if ira.a_number < irb.a_number
      when 'B'
        return next2_pc if ira.b_number < irb.b_number
      when 'AB'
        return next2_pc if ira.a_number < irb.b_number
      when 'BA'
        return next2_pc if ira.b_number < irb.a_number
      when 'F', 'I'
        return ira.a_number < irb.a_number && ira.b_number < irb.b_number
      when 'X'
        return ira.a_number < irb.b_number && ira.b_number < irb.a_number
      else
        raise ArgumentError, "Unknown instruction modifier #{@modifier}"
      end

      [context.program_counter + 1]
    end

    def spl(context)
      rpa = @a_operand.evaluate(context).first
      # Fork off another thread. One thread continues at the next instruction, the other at
      # the A-Pointer.
      [context.program_counter + 1, context.memory_core.rel_to_abs_addr(context.program_counter, rpa)]
    end
  end
end
