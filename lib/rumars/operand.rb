# frozen_string_literal: true

module RuMARS
  # An operand of the Instruction. Could be the A or B operand.
  class Operand
    attr_reader :address_mode, :value

    ADDRESS_MODES = %w[# $ @ * < { > }].freeze

    # @param address_mode [String] Address mode
    # @param value [String or Integer] Could be a label [String] that gets later relocated by the linker or an Integer number.
    def initialize(address_mode, value)
      raise ArgumentError, "Unknown addressing mode '#{address_mode}'" unless ADDRESS_MODES.include?(address_mode)

      @address_mode = address_mode
      @value = value
    end

    def to_s
      "#{@address_mode}#{@value}"
    end

    def deep_copy
      Operand.new(@address_mode.clone, @value)
    end
  end
end
