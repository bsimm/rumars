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
      @operator ? eval_binary(symbol_table, instruction_address) : eval_unary(symbol_table, instruction_address)
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

        symbol_table[operand] - instruction_address
      when Expression
        operand.eval(symbol_table, instruction_address)
      else
        raise RuntimeError, "Unknown operand class #{operand.class}"
      end
    end
  end
end
