# frozen_string_literal: true

require_relative 'textwm/window'

module RuMARS
  class RegisterWindow < TextWM::Window
    attr_reader :current_warrior
    attr_accessor :trace_index

    def initialize(textwm, tracer)
      super(textwm, 'Register Window')

      @tracer = tracer
      @trace_index = -1
    end

    def update
      @virt_term.clear
      @virt_term.right_clip = @virt_term.bottom_clip = true

      if (instruction = @tracer.instruction(@trace_index))
        puts instruction
      end

      super
    end

    def getch(char)
      case char
      when 'ArrowUp'
        @trace_index -= 1 if @trace_index >= -(@tracer.trace_count - 1)
      when 'ArrowDown'
        @trace_index += 1 if @trace_index < -1
      end

      true
    end
  end
end
