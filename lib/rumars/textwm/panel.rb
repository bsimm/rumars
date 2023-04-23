#
# Copyright (c) Chris Schlaeger <cs@taskjuggler.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#
# frozen_string_literal: true

module TextWM
  class Panel
    Button = Struct.new(:key, :label, :callback)

    def initialize(textwm)
      @textwm = textwm
      @textwm.register_panel(self)
      @buttons = []

      @accent_color = :red
      @text_color = :black
      @background_color = :white
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
      # Ignore buttons that have no label.
      buttons = @buttons.clone.delete_if { |b| b.label.nil? }

      t.set_cursor_position(@col, @row)

      if buttons.empty?
        # No buttons. Just draw a blank line.
        cprint(@text_color, @background_color, ' ' * @width)
        return
      end

      # Determine the size of the spaces between the buttons. The left edge
      # of the first button and the right edge of the last button should be
      # aligend with the view edges.
      buttons_length = buttons.map { |b| "#{b.key}-#{b.label}" }.join.length
      space_count = buttons.length - 1
      total_spaces_length = @width - buttons_length
      total_spaces_length = 0 if total_spaces_length.negative?

      if space_count.zero?
        # We just have a single button that gets centered on the line.
        spacer_length = total_spaces_length / 2
        extra_spaces = total_spaces_length % 2

        cprint(@text_color, @background_color, ' ' * (spacer_length + extra_spaces))
        print_button(buttons.first)
        cprint(@text_color, @background_color, ' ' * spacer_length)
      else
        # We have two or more buttons.
        spacer_length = total_spaces_length / space_count
        extra_spaces = total_spaces_length % space_count

        buttons[0..-2].each do |button|
          print_button(button)
          cprint(@text_color, @background_color, ' ' * (spacer_length + (extra_spaces.positive? ? 1 : 0)))
          extra_spaces -= 1
        end
        print_button(buttons.last)
      end
    end

    private

    def print_button(button)
      @textwm.terminal.bold_on
      cprint(@accent_color, @background_color, button.key)
      cprint(@text_color, @background_color, "-#{button.label}")
    end

    def cprint(foreground, background, text)
      t = @textwm.terminal

      t.color(foreground, background)
      t.print text
      t.attributes_off
    end
  end
end
