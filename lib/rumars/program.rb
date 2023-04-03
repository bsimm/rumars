# frozen_string_literal: true

require_relative 'expression'

module RuMARS
  # Intermediate representation of a REDCODE program as returned by the Parser.
  # A program consists of a set of instructions and meta information like
  # labels.
  class Program
    attr_accessor :start_address, :instructions, :labels, :name, :author

    def initialize
      @start_address = 0
      @instructions = []
      @labels = {}
      @name = ''
      @author = ''
      @strategy = ''
    end

    def append_instruction(instruction)
      @instructions << instruction
    end

    def size
      @instructions.size
    end

    def add_strategy(text)
      @strategy += "\n" unless @strategy.empty?

      @strategy += text
    end

    # Register a new label. If no value is given, it is assumed to be a label
    # for the next instruction to be appended.
    # @param [String] name of the label
    # @param [Integer] value associated with the label
    def add_label(name, value = @instructions.size)
      return false if symbol_defined?(name)

      @labels[name] = value
      true
    end

    def evaluate_expressions
      # Resolve the start address
      @start_address = @start_address.eval(@labels, 0) unless @start_address.is_a?(Integer)

      @instructions.each_with_index do |instruction, address|
        begin
          instruction.evaluate_expressions(@labels, address)
        rescue Expression::ExpressionError
          raise Expression::ExpressionError, instruction.to_s
        end
      end
    end

    def resolve_address(address)
      @labels.each do |name, adr|
        return name if address == adr
      end

      nil
    end

    private

    def symbol_defined?(name)
      @labels.include?(name)
    end
  end
end
