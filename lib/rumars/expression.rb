# frozen_string_literal: true

module RuMARS
  class Expression
    class ExpressionError < RuntimeError
    end

    def initialize(operand1, operator, operand2)
      @operand1 = operand1
      @operator = operator
      @operand2 = operand2
    end

    def eval(symbol_table, instruction_address = 0)
      begin
        eval_recursive(symbol_table, instruction_address)
      rescue ExpressionError => e
        raise ExpressionError, "#{self}: #{e.message}"
      end
    end

    def eval_recursive(symbol_table, instruction_address)
      @operator ? eval_binary(symbol_table, instruction_address) : eval_unary(symbol_table, instruction_address)
    end

    def to_s
      @operator ? "#{@operand1} #{@operator} #{@operand2}" : @operand1.to_s
    end

    private

    def eval_unary(symbol_table, instruction_address)
      eval_operand(@operand1, symbol_table, instruction_address)
    end

    def eval_binary(symbol_table, instruction_address)
      op1 = eval_operand(@operand1, symbol_table, instruction_address)
      op2 = eval_operand(@operand2, symbol_table, instruction_address)

      case @operator
      when '+'
        op1 + op2
      when '-'
        op1 - op2
      when '*'
        op1 * op2
      when '/'
        raise ExpressionError, 'Division by zero' if op2.zero?

        op1 / op2
      when '%'
        raise ExpressionError, 'Modulo by zero' if op2.zero?

        op1 % op2
      else
        raise ArgumentError, "Unknown operator #{@operator}"
      end
    end

    def eval_operand(operand, symbol_table, instruction_address)
      case operand
      when Integer
        operand
      when String
        raise ExpressionError, "Unknown symbol #{operand}" unless symbol_table.include?(operand)

        symbol_table[operand].to_i - instruction_address
      when Expression
        operand.eval_recursive(symbol_table, instruction_address)
      else
        raise "Unknown operand class #{operand.class}"
      end
    end
  end
end
