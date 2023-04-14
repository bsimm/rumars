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
      vertical_scrollbar.enable(true)
    end

    def update
      @virt_term.clear
      @virt_term.bottom_clip = true
      t = @textwm.terminal

      program_counters = @mars.scheduler.program_counters
      core = @mars.memory_core
      line_length = @width - 2 - 5

      (@height - 2).times do |line|
        line_address = (@view_top_line + line) * line_length
        break if line_address >= MemoryCore.size

        print t.ansi_code(:color, :white, :blue)
        print "#{aformat(line_address)}:"
        line_length.times do |col|
          address = line_address + col
          break if address >= MemoryCore.size

          instruction = core.peek(address)

          fg_color = TextWM::Terminal::FGCOLORS.keys[8 + instruction.pid]
          print t.ansi_code(:color, fg_color, program_counters.include?(address) ? :white : :blue)
          print instruction_character(instruction)
        end
        puts
      end

      super
    end

    def update_vertical_scrollbar
      line_length = @width - 2 - 5
      line_count = (MemoryCore.size / line_length) + ((MemoryCore.size % line_length).zero? ? 0 : 1)
      vertical_scrollbar.update(@height - 2, line_count, @height - 2, @view_top_line)
    end

    def getch(char)
      line_length = @width - 2 - 5
      lines = (MemoryCore.size / line_length) + (MemoryCore.size % line_length ? 1 : 0)
      last_top_line = lines - (@height - 2)
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
