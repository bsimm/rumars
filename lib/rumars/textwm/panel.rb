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

      t.set_cursor_position(@col, @row)
      button_length = buttons.map { |b| "#{b.key}-#{b.label}" }.join.length
      spacer = if @buttons.length > 1 && @width > button_length
                 ' ' * ((@width - button_length) / (@buttons.length - 1))
               else
                 ''
               end
      t.print buttons.map { |b| "#{col.wrap(b.key).color(:red)}-#{b.label}" }.join(spacer)
    end
  end
end
