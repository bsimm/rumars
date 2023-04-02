# frozen_string_literal: true

module TextWM
  class ButtonRow
    BUTTONS = %w[F1-Help F2-Brkpt F4-PrevWin F5-NextWin F8-Step F9-Run].freeze

    def initialize(textwm)
      @textwm = textwm
      @textwm.register_decoration(self)
    end

    def resize(col, row, width, _)
      @col = col
      @row = row
      @width = width
    end

    def update
      t = @textwm.terminal

      t.set_cursor_position(@col, @row)
      button_length = BUTTONS.join.length
      spacer = ' ' * ((@width - button_length) / (BUTTONS.length - 1))
      t.print BUTTONS.join(spacer)
    end
  end
end
