# frozen_string_literal: true

require_relative 'terminal'
require_relative 'window'
require_relative 'splits'

Signal.trap('WINCH') { throw :signal_terminal_resized }

module TextWM
  class WindowManager
    attr_reader :terminal

    def initialize
      @terminal = Terminal.new
      @terminal.reset
      @terminal.clear

      @splits = nil
      @windows = []
      @active_window = nil
      @decorations = []
    end

    def resize
      raise 'Screen must be split first before calling resize' unless @splits

      columns, rows = @terminal.size

      return if columns < 40 || rows < 20

      @splits.resize(0, 0, columns, rows)
    end

    def split(direction, *ratios)
      @splits = Splits.new(direction, *ratios)
    end

    def register_window(window)
      @windows << window
      activate_window(window)
    end

    def register_decoration(decoration)
      @decorations << decoration
    end

    def activate_window(window)
      raise 'Unknown window' unless @windows.include?(window)

      @windows.each do |w|
        w.active = (w == window)
      end
      @active_window = window
    end

    def update_windows
      @windows.each { |window| window.update }
      @decorations.each { |decoration| decoration.update }

      @active_window.show_cursor
    end

    def event_loop
      loop do
        update_windows

        c = nil
        catch(:signal_terminal_resized) do
          c = @terminal.getch
        end

        case c
        when 'F5'
          activate_window(@windows[(@windows.size + @windows.index(@active_window) - 1) % @windows.size])
        when 'F6'
          activate_window(@windows[(@windows.index(@active_window) + 1) % @windows.size])
        when 'q'
          break
        when nil
          resize
        else
          break unless @active_window.getch(c)
        end
      end

      @terminal.clear
      @terminal.reset
    end
  end
end
