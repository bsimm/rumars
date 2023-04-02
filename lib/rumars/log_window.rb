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

    # Just a dummy method so we can redirect $stdout to the LogWindow.
    def write(_, _, **_) end
  end
end
