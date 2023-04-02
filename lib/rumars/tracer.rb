# frozen_string_literal: true

require_relative 'trace_instruction'

module RuMARS
  class Tracer
    def initialize
      @trace = []
      @current_instruction = nil
      @current_operand = nil
    end

    def next_instruction(address, instruction)
      @trace << (@current_instruction = TraceInstruction.new(address, instruction))
    end

    def processing_instruction
      @current_operand = nil
    end

    def processing_a_operand
      @current_operand = @current_instruction.a_operand || @current_instruction.new_a_operand
    end

    def processing_b_operand
      @current_operand = @current_instruction.b_operand || @current_instruction.new_b_operand
    end

    def operation(text)
      @current_instruction.operation(text)
    end

    def program_counters(pcs)
      @current_instruction.program_counters(pcs)
    end

    def log_operand(operand)
      @current_operand.log(operand)
    end

    def log_load(address, instruction)
      raise "instruction load" unless @current_operand
      @current_operand.log_load(address, instruction)
    end

    def log_store(address, instruction)
      (@current_operand || @current_instruction).log_store(address, instruction)
    end

    def last
      @trace.last
    end
  end
end
