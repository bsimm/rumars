# frozen_string_literal: true

require 'rainbow'

module TextWM
  class Panel
    Button = Struct.new(:key, :label, :callback)

    def initialize(textwm)
      @textwm = textwm
      @textwm.register_panel(self)
      @buttons = []
    end

    def add_button(key, label, &callback)
      @buttons << Button.new(key, label, callback)
    end

    def getch(char)
      @buttons.each do |button|
        if button.key == char
          button.callback.call
          return true
        end
      end

      false
    end

    def resize(col, row, width, _)
      @col = col
      @row = row
      @width = width
    end

    def update
      t = @textwm.terminal
      col = Rainbow.new
      # Ignore buttons that have no label.
      buttons = @buttons.clone.delete_if { |b| b.label.nil? }

      buttons_length = buttons.map { |b| "#{b.key}-#{b.label}" }.join.length
      spacer_length = if buttons.length > 1 && @width > buttons_length
                        (@width - buttons_length) / (buttons.length - 1)
                      else
                        0
                      end
      colored_buttons = buttons.map { |b| "#{col.wrap(b.key).color(:red)}-#{b.label}" }
      extra_spaces = @width - buttons_length - (spacer_length * (buttons.length - 1))
      extra_spaces = 0 if extra_spaces.negative?

      button_str = +''
      colored_buttons[0..-2].each do |button|
        button_str += button + (' ' * (spacer_length + (extra_spaces.positive? ? 1 : 0)))
        extra_spaces -= 1
      end
      button_str += colored_buttons.last

      t.set_cursor_position(@col, @row)
      t.print button_str
    end
  end
end
