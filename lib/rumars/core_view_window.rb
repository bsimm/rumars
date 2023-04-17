# frozen_string_literal: true

require_relative 'textwm/window'
require_relative 'format'

module RuMARS
  class CoreViewWindow < TextWM::Window
    COLORS = %i[silver red green yellow blue magenta cyan aqua indianred].freeze

    include Format

    def initialize(textwm, mars)
      super(textwm, 'Core View Window')
      @mars = mars
      @view_top_line = 0
      @force_update = true

      vertical_scrollbar.enable(true)

      @text_color = :white
      @background_color = :blue
      @pc_color = :white
    end

    def resize(col, row, width, height)
      @force_update = true

      super
    end

    def update
      core = @mars.memory_core
      if core.io_trace && core.io_trace.empty? && !@force_update
        # The I/O trace is empty. Nothing has changed.
        super
        @force_update = false
        return
      end

      @virt_term.clear
      @virt_term.bottom_clip = true
      t = @textwm.terminal

      ipl = instructions_per_line
      traces_by_lines = split_io_trace_by_lines

      (@height - 2).times do |line|
        line_address = (@view_top_line + line) * ipl
        break if line_address >= MemoryCore.size

        print t.ansi_code(:color, @text_color, @background_color)
        print "#{aformat(line_address)}:"
        ipl.times do |col|
          address = line_address + col
          break if address >= MemoryCore.size

          instruction = core.peek(address)

          fg_color = TextWM::Terminal::FGCOLORS.keys[8 + instruction.pid]
          trace = traces_by_lines[line]&.find { |trc| trc.address == address }
          bg_color =
            if trace.nil?
              @background_color
            elsif trace.operation == :pc
              @pc_color
            else
              TextWM::Terminal::BGCOLORS.keys[8 + trace.pid]
            end

          print t.ansi_code(:color, fg_color, bg_color)
          print instruction_character(instruction)
        end
        print t.ansi_code(:color, @text_color, @background_color)
        puts
      end
      core.io_trace&.clear

      super
    end

    def update_vertical_scrollbar
      vertical_scrollbar.update(@height - 2, lines_of_core_memory, @height - 2, @view_top_line)
    end

    def getch(char)
      last_top_line = lines_of_core_memory - (@height - 2)
      last_top_line = 0 if last_top_line.negative?

      case char
      when 'Home'
        @view_top_line = 0
      when 'End'
        @view_top_line = last_top_line
      when 'ArrowUp'
        @view_top_line -= 1 if @view_top_line >= 1
      when 'ArrowDown'
        @view_top_line += 1 if @view_top_line < last_top_line
      when 'PageUp'
        @view_top_line -= @height - 2
        @view_top_line = 0 if @view_top_line.negative?
      when 'PageDown'
        @view_top_line += @height - 2
        @view_top_line = last_top_line if @view_top_line > last_top_line
      end

      super
    end

    private

    # Number of instructions we can show on each line. That's the window
    # width minus the 2 frame lines, 4 digits for the address and the colon.
    def instructions_per_line
      @width - 2 - 4 - 1
    end

    def lines_of_core_memory
      ipl = instructions_per_line
      (MemoryCore.size / ipl) + (MemoryCore.size % ipl ? 1 : 0)
    end

    def split_io_trace_by_lines
      lines = []

      ipl = instructions_per_line
      return lines if ipl.zero? || (io_trace = @mars.memory_core.io_trace).nil?

      first_visible_address = @view_top_line * ipl
      last_visible_address = ((@view_top_line + (@height - 2)) * ipl) - 1

      io_trace.each do |trace|
        address = trace.address
        next if address < first_visible_address || address > last_visible_address

        line_no = (address - first_visible_address) / ipl
        lines[line_no] ||= []
        lines[line_no] << trace
      end

      lines
    end

    def instruction_character(instruction)
      case instruction.opcode
      when 'DAT'
        'X'
      when 'ADD'
        '+'
      when 'SUB'
        '-'
      when 'MUL'
        '*'
      when 'DIV'
        '/'
      when 'MOD'
        '%'
      when 'MOV'
        'M'
      when 'NOP'
        '.'
      when 'JMP', 'JMZ', 'JMN', 'DJN', 'CMP', 'SLT', 'SEC', 'SNE'
        'J'
      when 'SPL'
        '<'
      else
        '?'
      end
    end
  end
end
