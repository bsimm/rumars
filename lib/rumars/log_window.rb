# frozen_string_literal: true

require_relative 'textwm/window'

module RuMARS
  class LogWindow < TextWM::Window
    def initialize(textwm)
      super(textwm, 'Log Window')
    end

    def update
      @virt_term.right_clip = true

      super
    end
  end
end
