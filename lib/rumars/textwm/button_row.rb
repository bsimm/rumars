# frozen_string_literal: true

module TextWM
  class ButtonRow
    BUTTONS = [%w[F1 Help], %w[F2 Brkpt], %w[F4 PrevWin], %w[F5 NextWin], %w[F6 Reload],
               %w[F7 Restart], %w[F8 Step], %w[F9 Run]].freeze

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
      button_length = BUTTONS.map { |b| b.join('-') }.join.length
      spacer = ' ' * ((@width - button_length) / (BUTTONS.length - 1))
      t.print BUTTONS.map { |b| b.join('-') }.join(spacer)
    end
  end
end
