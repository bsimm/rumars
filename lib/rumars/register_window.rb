# frozen_string_literal: true

require_relative 'textwm/window'

module RuMARS
  class RegisterWindow < TextWM::Window
    attr_reader :current_warrior

    def initialize(textwm, tracer)
      super(textwm, 'Register Window')

      @tracer = tracer
    end

    def update
      @virt_term.clear
      @virt_term.right_clip = @virt_term.bottom_clip = true

      if (instruction = @tracer.last)
        puts instruction
      end

      super
    end
  end
end
