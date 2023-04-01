# frozen_string_literal: true

require_relative 'textwm/window'

module RuMARS
  class LogWindow < TextWM::Window
    def initialize(textwm)
      super(textwm, 'Log Window')
    end
  end
end
