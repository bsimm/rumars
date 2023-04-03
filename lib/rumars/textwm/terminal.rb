# frozen_string_literal: true

require 'io/console'
require 'stringio'

module TextWM
  # This class provides access to the output terminal and keyboard input. It
  # assumes that the terminal is a VT100 compatible terminal.
  class Terminal
    KEYSTROKES = {
      "\177" => 'Backspace',
      "\e" => 'Escape',
      "\e[3~" => 'Delete',
      "\e[5~" => 'PageUp',
      "\e[6~" => 'PageDown',
      "\e[A" => 'ArrowUp',
      "\e[B" => 'ArrowDown',
      "\e[C" => 'ArrowRight',
      "\e[D" => 'ArrowLeft',
      "\eOP" => 'F1',
      "\eOQ" => 'F2',
      "\eOR" => 'F3',
      "\eOS" => 'F4',
      "\e[15~" => 'F5',
      "\e[17~" => 'F6',
      "\e[18~" => 'F7',
      "\e[19~" => 'F8',
      "\e[20~" => 'F9',
      "\e[21~" => 'F10',
      "\e[24~" => 'F12',
      "\ea" => 'ALT-a',
      "\eb" => 'ALT-b',
      "\ec" => 'ALT-c',
      "\ed" => 'ALT-d',
      "\ee" => 'ALT-e',
      "\ef" => 'ALT-f',
      "\eg" => 'ALT-g',
      "\eh" => 'ALT-h',
      "\ei" => 'ALT-i',
      "\ej" => 'ALT-j',
      "\ek" => 'ALT-k',
      "\el" => 'ALT-l',
      "\em" => 'ALT-m',
      "\en" => 'ALT-n',
      "\eo" => 'ALT-o',
      "\ep" => 'ALT-p',
      "\eq" => 'ALT-q',
      "\er" => 'ALT-r',
      "\es" => 'ALT-s',
      "\et" => 'ALT-t',
      "\eu" => 'ALT-u',
      "\ev" => 'ALT-v',
      "\ew" => 'ALT-w',
      "\ex" => 'ALT-x',
      "\ey" => 'ALT-y',
      "\ez" => 'ALT-z',
      "\r" => 'Return',
      "\t" => 'Tab'
    }.freeze
    KEYCODES = KEYSTROKES.invert.freeze

    def initialize(out = $stdout, inp = $stdin)
      @out = out
      @inp = inp
    end

    # Reset the terminal to the initial state.
    def reset
      send("\ec")
    end

    # Clear the whole screen.
    def clear
      send("\e[H\e[2J")
    end

    #
    # Screen size related methods
    #

    # Return the size of the terminal as lines and columns.
    # @return [Array] [columns, lines]
    def size
      lincol =
        if @out.respond_to?('winsize')
          begin
            @out.winsize
          rescue Errno::ENOTTY
            return [80, 40]
          end
        else
          IO.console.winsize
        end
      [lincol[1], lincol[0]]
    end

    # Return the number of lines that the terminal has.
    def lines
      size[1]
    end

    # Return the number of columns that the terminal has.
    def columns
      size[0]
    end

    #
    # Cursor related methods
    #

    # Get the current cursor position on the terminal.
    # @return [Array] [column, line]
    def cursor_position
      send("\e[6n")
      answer = receive
      line, column = answer[2..].split(';')

      # Terminals tradionally use 1,1 as coordinate for the top left corner.
      # We prefer to use 0, 0.
      [column.to_i - 1, line.to_i - 1]
    end

    # Set the cursor to the given position.
    def set_cursor_position(column, line)
      # Terminals tradionally use 1,1 as coordinate for the top left corner.
      # We prefer to use 0, 0.
      send("\e[#{line + 1};#{column + 1}H")
    end

    # Hide the cursor.
    def hide_cursor
      send("\e[?25l")
    end

    # Show the cursor.
    def show_cursor
      send("\e[?25h")
    end

    #
    # Input and Output related methods
    #

    # Read a single keystroke from the keyboard. For special keys the human
    # readable name of the key is returned.
    def getch
      str = @inp.getch

      if str == "\e"
        begin
          str << @inp.read_nonblock(4)
        rescue IO::EAGAINWaitReadable
        end
      end

      KEYSTROKES[str] || str
    end

    # Same as IO.puts.
    def puts(str = '')
      @out.puts(str)
    end

    # Same as IO.print
    def print(str)
      @out.print(str)
    end

    def mocked?
      @inp.is_a?(StringIO)
    end

    def mock_edit(file_name)
      @inp.mock_edit(file_name)
    end

    #
    # Font attribute related methods
    #

    # Turn off all character attributes.
    def attributes_off
      send("\e[0m")
    end

    # Turn on bold mode
    def bold_on
      send("\e[1m")
    end

    # Turn on low intensity mode
    def low_intensity_on
      send("\e[2m")
    end

    # Turn character underlining on
    def underline_on
      send("\e[4m")
    end

    # Turn reverse video mode on
    def reverse_on
      send("\e[7m")
    end

    private

    def send(sequence)
      @out.print sequence
      @out.flush if @out.respond_to?(:flush)
    end

    def receive
      s = ''
      @inp.rewind if mocked?
      while (c = @inp.getch) != 'R'
        raise "Could not receive cursor position sequence: '#{s}'" if c.nil?

        s += c if c
      end
      if mocked?
        # Rewind and clear the @inp StringIO to it won't be conflicting with
        # mocked user input during testing.
        @inp.rewind
        @inp.truncate(@inp.pos)
      end
      s
    end
  end
end
