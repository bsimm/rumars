# frozen_string_literal: true

module TextWM
  class VirtualTerminal
    attr_reader :cursor_column, :cursor_row
    attr_accessor :right_clip, :bottom_clip

    def initialize(columns, rows)
      @columns = columns
      @rows = rows

      @right_clip = @bottom_clip = false

      clear
    end

    def clear
      @buffer_lines = Array.new(@rows) { |_| ' ' * @columns }
      @cursor_row = 0
      @cursor_column = 0
    end

    def backspace
      return unless @cursor_column.positive?

      @cursor_column -= 1
      @buffer_lines[@cursor_row][@cursor_column] = ' '
    end

    def puts(str)
      print "#{str}\n"
    end

    def print(str)
      str.each_char do |c|
        if c == "\n"
          @cursor_row += 1
          @cursor_column = 0
        else
          next if (@right_clip && @cursor_row >= @columns - 1) ||
                  (@cursor_row >= @rows || @cursor_column >= @columns)

          @buffer_lines[@cursor_row][@cursor_column] = c
          @cursor_column += 1
        end

        if @cursor_column >= @columns
          # The cursor moved past the right edge of the virtual screen.
          # Move cursor to beginning of next line
          @cursor_column = 0
          @cursor_row += 1
        end

        next if @cursor_row < @rows || @bottom_clip

        # The cursor moved past the bottom of the virtual screen.
        # The cursor remains on the last line.
        @cursor_row = @rows - 1

        # The first line is discarded.
        @buffer_lines.shift
        # A new blank line is added at the bottom.
        @buffer_lines << (' ' * @columns)
      end
    end

    def line(index)
      @buffer_lines[index]
    end
  end
end
