# frozen_string_literal: true

require_relative 'operand'
require_relative 'format'

module RuMARS
  class TraceOperand
    attr_reader :pointer, :instruction, :post_incr_instr, :loads, :stores

    include Format

    def initialize
      @pointer = nil
      @instruction = nil
      @post_incr_instr = nil
      @loads = []
      @stores = []
    end

    def log(operand)
      @pointer = operand.pointer
      @instruction = operand.instruction&.to_s
      @post_incr_instr = operand.post_incr_instr&.to_s
    end

    def log_load(address, instruction)
      @loads << [address, instruction]
    end

    def log_store(address, instruction)
      @stores << [address, instruction]
    end

    def to_s
      "PTR: #{aformat(@pointer)}                INS:         #{iformat(@instruction)}\n" \
        "  LOAD1: #{aiformat(@loads[0])} PII:         #{iformat(@post_incr_instr)}\n" \
        "  LOAD2: #{aiformat(@loads[1])} STORE: #{aiformat(@stores[0])}" \
    end
  end
end
