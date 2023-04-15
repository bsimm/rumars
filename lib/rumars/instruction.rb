# frozen_string_literal: true

require_relative 'operand'
require_relative 'memory_core'

module RuMARS
  OPCODES = %w[DAT MOV ADD SUB MUL DIV MOD JMP JMZ JMN DJN CMP SLT SPL].freeze
  MODIFIERS = %w[A B AB BA F X I].freeze

  ExecutionContext = Struct.new(:modifier, :program_counter, :memory_core, :pid, :base_address)

  # A REDCODE instruction that is stored in the core memory.
  # https://corewar-docs.readthedocs.io/en/latest/redcode/
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

    @tracer = nil

    # Accessor for @tracer
    class << self
      attr_accessor :tracer
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

    def a_number
      @a_operand&.number
    end

    def a_number=(number)
      @a_operand.number = number
      self.class.tracer&.log_store(@address, to_s)
    end

    def increment_a_number
      n = @a_operand.number = MemoryCore.fold(a_number + 1)
      self.class.tracer&.log_store(@address, to_s)
      n
    end

    def decrement_a_number
      n = @a_operand.number = MemoryCore.fold(a_number - 1)
      self.class.tracer&.log_store(@address, to_s)
      n
    end

    def b_number
      @b_operand&.number
    end

    def b_number=(number)
      @b_operand.number = number
      self.class.tracer&.log_store(@address, to_s)
    end

    def increment_b_number
      n = @b_operand.number = MemoryCore.fold(b_number + 1)
      self.class.tracer&.log_store(@address, to_s)
      n
    end

    def decrement_b_number
      n = @b_operand.number = MemoryCore.fold(b_number - 1)
      self.class.tracer&.log_store(@address, to_s)
      n
    end

    def evaluate_expressions(symbol_table, instruction_address)
      @a_operand.evaluate_expressions(symbol_table, instruction_address)
      @b_operand.evaluate_expressions(symbol_table, instruction_address)
    end

    def execute(memory_core, program_counter, pid, base_address)
      bus = InstructionBus.new(memory_core, base_address, program_counter, @modifier, pid)

      # Prepare the A-Operand
      self.class.tracer&.processing_a_operand
      bus.a_operand = @a_operand.evaluate(bus)
      bus.a_operand.instruction = bus.a_operand.instruction.deep_copy
      @a_operand.post_increment(bus, bus.a_operand)
      self.class.tracer&.log_operand(bus.a_operand)

      # Prepare the B-Operand
      self.class.tracer&.processing_b_operand
      bus.b_operand = @b_operand.evaluate(bus)
      @b_operand.post_increment(bus, bus.b_operand)
      self.class.tracer&.log_operand(bus.b_operand)

      self.class.tracer&.processing_instruction
      next_pc = [program_counter + 1]

      case @opcode
      when 'ADD'
        arith('+', bus)
      when 'DAT'
        self.class.tracer&.operation('Terminating current thread')
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
      when 'NOP'
        # Do nothing
      when 'SEQ', 'CMP'
        next_pc = seq(bus)
      when 'SNE'
        next_pc = sne(bus)
      when 'SLT'
        next_pc = slt(bus)
      when 'SPL'
        next_pc = spl(bus)
      when 'SUB'
        arith('-', bus)
      else
        raise "Unknown opcode #{@opcode} at address #{program_counter}"
      end

      next_pc
    end

    # Create an identical deep copy.
    def deep_copy
      Instruction.new(@pid, @opcode.clone, @modifier.clone, @a_operand.deep_copy, @b_operand&.deep_copy)
    end

    def to_s
      "#{@opcode}.#{@modifier} #{@a_operand}, #{@b_operand}"
    end

    def ==(other)
      @opcode == other.opcode && @modifier == other.modifier &&
        @a_operand == other.a_operand && @b_operand == other.b_operand
    end

    private

    def arith(op, bus)
      ira = bus.a_operand.instruction
      irb = bus.b_operand.instruction

      case @modifier
      when 'A'
        irb.a_number = arith_op(irb.a_number, op, ira.a_number)
      when 'B'
        irb.b_number = arith_op(irb.b_number, op, ira.b_number)
      when 'AB'
        irb.b_number = arith_op(irb.b_number, op, ira.a_number)
      when 'BA'
        irb.a_number = arith_op(irb.a_number, op, ira.b_number)
      when 'F', 'I'
        begin
          irb.a_number = arith_op(irb.a_number, op, ira.a_number)
        rescue DivBy0Error => e
        end
        # The b operation must be computed even if the a operation had a division by 0
        irb.b_number = arith_op(irb.b_number, op, ira.b_number)
        raise e if e
      when 'X'
        begin
          irb.b_number = arith_op(irb.a_number, op, ira.b_number)
        rescue DivBy0Error => e
        end
        # The b operation must be computed even if the a operation had a division by 0
        irb.a_number = arith_op(irb.b_number, op, ira.a_number)
        raise e if e
      else
        raise ArgumentError, "Unknown instruction modifier #{@modifier}"
      end
      irb.pid = bus.pid
    end

    def arith_op(op1, operator, op2)
      case operator
      when '+'
        result = MemoryCore.fold(op1 + op2)
        self.class.tracer&.operation("Computing #{op1} + #{op2} = #{result}")
      when '-'
        result = MemoryCore.fold(op1 - op2)
        self.class.tracer&.operation("Computing #{op1} - #{op2} = #{result}")
      when '*'
        result = MemoryCore.fold(op1 * op2)
        self.class.tracer&.operation("Computing #{op1} * #{op2} = #{result}")
      when '/'
        raise DivBy0Error if op2.zero?

        result = op1 / op2
        self.class.tracer&.operation("Computing #{op1} / #{op2} = #{result}")
      when '%'
        raise DivBy0Error if op2.zero?

        result = op1 % op2
        self.class.tracer&.operation("Computing #{op1} % #{op2} = #{result}")
      else
        raise ArgumentError, "Unknown operator #{operator}"
      end

      result
    end

    def djn(bus)
      rpa = bus.a_operand.pointer
      irb = bus.b_operand.instruction

      next_pc = [bus.program_counter + rpa]
      irb.pid = pid

      case @modifier
      when 'A', 'BA'
        irb.decrement_a_number
        self.class.tracer&.operation("Jumping if irb A-Number (#{irb.a_number}) != 0")
        return next_pc unless irb.a_number.zero?
      when 'B', 'AB'
        irb.decrement_b_number
        self.class.tracer&.operation("Jumping if irb B-Number (#{irb.b_number}) != 0")
        return next_pc unless irb.b_number.zero?
      when 'F', 'X', 'I'
        irb.decrement_a_number
        irb.decrement_b_number
        self.class.tracer&.operation("Jumping if not (irb A-Number (#{irb.a_number}) == 0 && " \
                                     "irb B-Number (#{irb.b_number}) == 0)")
        return next_pc unless irb.a_number.zero? && irb.b_number.zero?
      else
        raise ArgumentError, "Unknown instruction modifier #{@modifier}"
      end

      [bus.program_counter + 1]
    end

    def jmp(bus)
      rpa = bus.a_operand.pointer

      # Return a PC-relative jump destination address
      next_pc = MemoryCore.fold(bus.program_counter + rpa)
      self.class.tracer&.operation("Jumping to #{next_pc}")
      [next_pc]
    end

    def jmz(bus)
      rpa = bus.a_operand.pointer
      irb = bus.b_operand.instruction

      # PC-relative jump destination address
      jump_pc = [MemoryCore.fold(bus.program_counter + rpa)]

      case @modifier
      when 'A', 'BA'
        self.class.tracer&.operation("Jumping if irb A-Number (#{irb.a_number}) == 0")
        return jump_pc if irb.a_number.zero?
      when 'B', 'AB'
        self.class.tracer&.operation("Jumping to #{jump_pc} if irb B-Number (#{irb.b_number}) == 0")
        return jump_pc if irb.b_number.zero?
      when 'F', 'X', 'I'
        # Jump of both of the fields are zero
        self.class.tracer&.operation("Jumping if ira A-Number (#{irb.a_number}) == 0 && irb B-Number (#{irb.b_number}) == 0")
        return jump_pc if irb.a_number.zero? && irb.b_number.zero?
      else
        raise ArgumentError, "Unknown instruction modifier #{@modifier}"
      end

      [bus.program_counter + 1]
    end

    def jmn(bus)
      rpa = bus.a_operand.pointer
      irb = bus.b_operand.instruction

      jump_pc = [MemoryCore.fold(bus.program_counter + rpa)]

      case @modifier
      when 'A', 'BA'
        self.class.tracer&.operation("Jumping if irb A-Number (#{irb.a_number}) != 0")
        return jump_pc unless irb.a_number.zero?
      when 'B', 'AB'
        self.class.tracer&.operation("Jumping if irb B-Number (#{irb.b_number}) != 0")
        return jump_pc unless irb.b_number.zero?
      when 'F', 'X', 'I'
        # Jump if either of the fields are zero
        self.class.tracer&.operation("Jumping unless ira A-Number (#{irb.a_number}) == 0 && " \
                                     "irb B-Number (#{irb.b_number}) == 0")
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
        self.class.tracer&.operation('Replacing B operand A-Number with A operand A-Number')
        irb.a_number = ira.a_number
        irb.pid = bus.pid
      when 'B'
        self.class.tracer&.operation('Replacing B operand B-Number with A operand B-Number')
        irb.b_number = ira.b_number
        irb.pid = bus.pid
      when 'AB'
        self.class.tracer&.operation('Replacing B operand B-Number with A operand A-Number')
        irb.b_number = ira.a_number
        irb.pid = bus.pid
      when 'BA'
        self.class.tracer&.operation('Replacing B operand A-Number with A operand B-Number')
        irb.a_number = ira.b_number
        irb.pid = bus.pid
      when 'F'
        self.class.tracer&.operation('Repl. B op A-Num with A op A-Num and B op B-Num with A op B-Num')
        irb.a_number = ira.a_number
        irb.b_number = ira.b_number
        ira.pid = bus.pid
        irb.pid = bus.pid
      when 'X'
        self.class.tracer&.operation('Repl. B op A-Num with A op B-Num and B op B-Num with A op A-Num')
        irb.a_number = ira.b_number
        irb.b_number = ira.a_number
        ira.pid = bus.pid
        irb.pid = bus.pid
      when 'I'
        # Copies entire instruction
        self.class.tracer&.operation('Copy A instruction into B instruction')
        # Ensure ownership of modified instruction
        ira.pid = bus.pid
        bus.memory_core.store_relative(bus.base_address, bus.program_counter, wpb, ira)
      else
        raise ArgumentError, "Unknown instruction modifier #{@modifier}"
      end
    end

    def seq(bus)
      ira = bus.a_operand.instruction
      irb = bus.b_operand.instruction

      next2_pc = [bus.program_counter + 2]

      case @modifier
      when 'A'
        self.class.tracer&.operation("Jumping if ira A-Number (#{ira.a_number}) == irb A-Number (#{irb.a_number})")
        return next2_pc if ira.a_number == irb.a_number
      when 'B'
        self.class.tracer&.operation("Jumping if ira B-Number (#{ira.b_number}) == irb B-Number (#{irb.b_number})")
        return next2_pc if ira.b_number == irb.b_number
      when 'AB'
        self.class.tracer&.operation("Jumping if ira A-Number (#{ira.a_number}) == irb B-Number (#{irb.b_number})")
        return next2_pc if ira.a_number == irb.b_number
      when 'BA'
        self.class.tracer&.operation("Jumping if ira B-Number (#{ira.b_number}) == irb A-Number (#{irb.a_number})")
        return next2_pc if ira.b_number == irb.a_number
      when 'F'
        self.class.tracer&.operation("Jumping if ira B-Number (#{ira.b_number}) == irb A-Number (#{irb.a_number}) &&" \
                                     "ira B-Number (#{ira.b_number}) == irb B-Number (#{irb.b_number})")
        return next2_pc if ira.a_number == irb.a_number && ira.b_number == irb.b_number
      when 'X'
        self.class.tracer&.operation("Jumping if ira A-Number (#{ira.a_number}) == irb B-Number (#{irb.b_number}) &&" \
                                     "ira B-Number (#{ira.b_number}) == irb A-Number (#{irb.a_number})")
        return next2_pc if ira.a_number == irb.b_number && ira.b_number == irb.a_number
      when 'I'
        self.class.tracer&.operation("Jumping if ira (#{ira}) == irb (#{irb})")
        return next2_pc if ira == irb
      else
        raise ArgumentError, "Unknown instruction modifier #{@modifier}"
      end

      [bus.program_counter + 1]
    end

    def sne(bus)
      ira = bus.a_operand.instruction
      irb = bus.b_operand.instruction

      next2_pc = [bus.program_counter + 2]

      case @modifier
      when 'A'
        self.class.tracer&.operation("Jumping if ira A-Number (#{ira.a_number}) != irb A-Number (#{irb.a_number})")
        return next2_pc if ira.a_number != irb.a_number
      when 'B'
        self.class.tracer&.operation("Jumping if ira B-Number (#{ira.b_number}) != irb B-Number (#{irb.b_number})")
        return next2_pc if ira.b_number != irb.b_number
      when 'AB'
        self.class.tracer&.operation("Jumping if ira A-Number (#{ira.a_number}) != irb B-Number (#{irb.b_number})")
        return next2_pc if ira.a_number != irb.b_number
      when 'BA'
        self.class.tracer&.operation("Jumping if ira B-Number (#{ira.b_number}) != irb A-Number (#{irb.a_number})")
        return next2_pc if ira.b_number != irb.a_number
      when 'F'
        self.class.tracer&.operation("Jumping if ira B-Number (#{ira.b_number}) != irb A-Number (#{irb.a_number}) &&" \
                                     "ira B-Number (#{ira.b_number}) != irb B-Number (#{irb.b_number})")
        return next2_pc if ira.a_number != irb.a_number && ira.b_number != irb.b_number
      when 'X'
        self.class.tracer&.operation("Jumping if ira A-Number (#{ira.a_number}) != irb B-Number (#{irb.b_number}) &&" \
                                     "ira B-Number (#{ira.b_number}) != irb A-Number (#{irb.a_number})")
        return next2_pc if ira.a_number != irb.b_number && ira.b_number != irb.a_number
      when 'I'
        self.class.tracer&.operation("Jumping if ira (#{ira}) != irb (#{irb})")
        return next2_pc if ira != irb
      else
        raise ArgumentError, "Unknown instruction modifier #{@modifier}"
      end

      [bus.program_counter + 1]
    end

    def slt(bus)
      ira = bus.a_operand.instruction
      irb = bus.b_operand.instruction

      jump_pc = [bus.program_counter + 2]

      case @modifier
      when 'A'
        self.class.tracer&.operation("Jumping if ira A-Number (#{ira.a_number}) < irb A-Number (#{irb.a_number})")
        return jump_pc if ira.a_number < irb.a_number
      when 'B'
        self.class.tracer&.operation("Jumping if ira B-Number (#{ira.b_number}) < irb B-Number (#{irb.b_number})")
        return jump_pc if ira.b_number < irb.b_number
      when 'AB'
        self.class.tracer&.operation("Jumping if ira A-Number (#{ira.a_number}) < irb B-Number (#{irb.b_number})")
        return jump_pc if ira.a_number < irb.b_number
      when 'BA'
        self.class.tracer&.operation("Jumping if ira B-Number (#{ira.b_number}) < irb A-Number (#{irb.a_number})")
        return jump_pc if ira.b_number < irb.a_number
      when 'F', 'I'
        self.class.tracer&.operation("Jumping if ira A-Num (#{ira.a_number}) < irb A-Num (#{irb.a_number}) &&" \
                                     "ira B-Num (#{ira.b_number}) < irb B-Num (#{irb.b_number})")
        return jump_pc if ira.a_number < irb.a_number && ira.b_number < irb.b_number
      when 'X'
        self.class.tracer&.operation("Jumping if ira A-Num (#{ira.a_number}) < irb B-Num (#{irb.b_number}) &&" \
                                     "ira B-Num (#{ira.b_number}) < irb A-Num (#{irb.a_number})")
        return jump_pc if ira.a_number < irb.b_number && ira.b_number < irb.a_number
      else
        raise ArgumentError, "Unknown instruction modifier #{@modifier}"
      end

      [bus.program_counter + 1]
    end

    def spl(bus)
      rpa = bus.a_operand.pointer

      next_pc = MemoryCore.fold(bus.program_counter + rpa)
      self.class.tracer&.operation("Forking to #{next_pc}")
      # Fork off another thread. One thread continues at the next instruction, the other at
      # the A-Pointer.
      [bus.program_counter + 1, next_pc]
    end
  end
end
