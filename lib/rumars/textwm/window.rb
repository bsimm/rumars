#
# Copyright (c) Chris Schlaeger <cs@taskjuggler.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#
# frozen_string_literal: true

require_relative 'terminal'
require_relative 'virtual_terminal'
require_relative 'scrollbar'

module TextWM
  class Window
    attr_reader :name
    attr_accessor :active

    # @param textwm [TextWM]
    # @param name [String]
    def initialize(textwm, name)
      @textwm = textwm
      @textwm.register_window(self)
      @t = textwm.terminal
      @name = name
      @col = @row = @width = @height = nil

      @virt_term = VirtualTerminal.new(1, 1)
      @active = false
      @show_cursor = false

      @vertical_scrollbar = nil

      @active_frame_fg_color = :brightcyan
      @active_frame_bg_color = :black
      @passive_frame_fg_color = :cyan
      @passive_frame_bg_color = :black
      @active_window_title_fg_color = :black
      @active_window_title_bg_color = :brightcyan
      @passive_window_title_fg_color = :brightwhite
      @passive_window_title_bg_color = :black
    end

    # @param col [Integer]
    # @param row [Integer]
    # @param width [Integer]
    # @param height [Integer]
    def resize(col, row, width, height)
      @col = col
      @row = row
      @width = width
      @height = height

      @virt_term.resize(@width - 2, @height - 2) if @width > 2 && @height > 2
    end

    def update
      update_vertical_scrollbar

      print_frame_top

      # Frame sides and window content
      (@height - 2).times do |i|
        print_frame_line(i)
      end

      print_frame_bottom
    end

    def update_vertical_scrollbar
      @vertical_scrollbar&.update(@height - 2, @virt_term.line_count, @height - 2, @virt_term.view_top_line)
    end

    def visible?
      @width.positive? && @height.positive?
    end

    def vertical_scrollbar
      @vertical_scrollbar ||= Scrollbar.new(:vertical)
    end

    def show_cursor
      unless @show_cursor
        @t.hide_cursor
        return
      end

      vcol = @virt_term.cursor_column
      vrow = @virt_term.cursor_row

      @t.set_cursor_position(@col + 1 + vcol, @row + 1 + vrow)
      @t.show_cursor
    end

    def getch(char)
      case char
      when 'ArrowUp'
        @virt_term.scroll(1)
      when 'ArrowDown'
        @virt_term.scroll(-1)
      when 'PageUp'
        @virt_term.scroll(@height - 2)
      when 'PageDown'
        @virt_term.scroll(-(@height - 2))
      when 'Home'
        @virt_term.view_top_line = 0
      when 'End'
        @virt_term.view_top_line = @virt_term.line_count - (@height - 2)
      end

      true
    end

    def puts(str = '')
      @virt_term.puts(str)
    end

    def print(str)
      @virt_term.print(str)
    end

    def flush
    end

    private

    def print_frame_top
      @t.set_cursor_position(@col, @row)

      padding = (@width - @name.length - 4) / 2
      padding = 0 if padding.negative?

      fill = (@width - @name.length - 4) % 2

      set_frame_colors
      @t.print @active ? '╔' : '┌'
      @t.print (@active ? '═' : '─') * padding
      set_title_colors
      @t.print " #{@name} "
      set_frame_colors
      @t.print (@active ? '═' : '─') * (padding + fill)
      @t.print @active ? '╗' : '┐'
    end

    def print_frame_line(i)
      @t.set_cursor_position(@col, @row + i + 1)
      @t.print @active ? '║' : '│'
      @t.print @virt_term.line(i)
      @t.attributes_off
      set_frame_colors
      if @vertical_scrollbar&.enabled && @height >= 4
        # We need a window height of at least 4 to show the scrollbar
        @t.print @vertical_scrollbar.line(i)
      else
        @t.print @active ? '║' : '│'
      end
    end

    def print_frame_bottom
      @t.set_cursor_position(@col, @row + @height - 1)
      @t.print @active ? '╚' : '└'
      @t.print (@active ? '═' : '─') * (@width - 2) if @width >= 2
      @t.print @active ? '╝' : '┘'
      @t.attributes_off
    end

    def set_frame_colors
      if @active
        @t.color(@active_frame_fg_color, @active_frame_bg_color)
      else
        @t.color(@passive_frame_fg_color, @passive_frame_bg_color)
      end
    end

    def set_title_colors
      if @active
        @t.color(@active_window_title_fg_color, @active_window_title_bg_color)
      else
        @t.color(@passive_window_title_fg_color, @passive_window_title_bg_color)
      end
    end
  end
end
