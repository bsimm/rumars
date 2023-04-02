# frozen_string_literal: true

require_relative 'terminal'
require_relative 'virtual_terminal'

module TextWM
  class Window
    attr_accessor :active

    # @param textwm [TextWM]
    # @param name [String]
    # @param col [Integer]
    # @param row [Integer]
    # @param width [Integer]
    # @param height [Integer]
    def initialize(textwm, name)
      @textwm = textwm
      @textwm.register_window(self)
      @t = textwm.terminal
      @name = name
      @col = @row = @width = @height = nil

      @virt_term = VirtualTerminal.new(1, 1)
      @active = false
      @show_cursor = false
    end

    def resize(col, row, width, height)
      @col = col
      @row = row
      @width = width
      @height = height

      @virt_term.resize(@width - 2, @height - 2)
    end

    def update
      print_frame_top

      # Frame sides and window content
      (@height - 2).times do |i|
        print_frame_line(i)
      end

      print_frame_bottom
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
      end

      true
    end

    def puts(str = '')
      @virt_term.puts(str)
    end

    def print(str)
      @virt_term.print(str)
    end

    private

    def print_frame_top
      @t.set_cursor_position(@col, @row)

      padding = (@width - @name.length - 4) / 2
      fill = (@width - @name.length - 4) % 2

      @t.print @active ? '╔' : '┌'
      @t.print (@active ? '═' : '─') * padding
      @t.print " #{@name} "
      @t.print (@active ? '═' : '─') * (padding + fill)
      @t.print @active ? '╗' : '┐'
    end

    def print_frame_line(i)
      @t.set_cursor_position(@col, @row + i + 1)
      @t.print @active ? '║' : '│'
      @t.print @virt_term.line(i)
      @t.print @active ? '║' : '│'
    end

    def print_frame_bottom
      @t.set_cursor_position(@col, @row + @height - 1)
      @t.print @active ? '╚' : '└'
      @t.print (@active ? '═' : '─') * (@width - 2)
      @t.print @active ? '╝' : '┘'
    end
  end
end
