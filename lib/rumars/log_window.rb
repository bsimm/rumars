#
# Copyright (c) Chris Schlaeger <cs@taskjuggler.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#
# frozen_string_literal: true

require_relative 'textwm/window'

module RuMARS
  class LogWindow < TextWM::Window
    def initialize(textwm)
      super(textwm, 'Log Window')
      vertical_scrollbar.enable(true)
    end

    def update
      @virt_term.right_clip = true

      super
    end

    # Just a dummy method so we can redirect $stdout to the LogWindow.
    def write(_, _, **_) end
  end
end
