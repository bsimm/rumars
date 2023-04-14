# frozen_string_literal: true

require_relative 'textwm/window'

module RuMARS
  class RegisterWindow < TextWM::Window
    attr_accessor :trace_index

    def initialize(textwm, mars)
      super(textwm, 'Register Window')

      @mars = mars
      @trace_index = 0
      vertical_scrollbar.enable(true)
    end

    def update
      @virt_term.clear
      @virt_term.right_clip = @virt_term.bottom_clip = true

      pid = @mars.current_warrior&.pid
      if (instruction = @mars.tracer.instruction(@trace_index, pid))
        puts instruction
      end

      super
    end

    def update_vertical_scrollbar
      pid = @mars.current_warrior&.pid
      vertical_scrollbar.update(@height - 2, @mars.tracer.trace_count(pid), 1, @trace_index)
    end

    def getch(char)
      pid = @mars.current_warrior&.pid
      last_index = @mars.tracer.trace_count(pid) - 1

      case char
      when 'ArrowUp'
        @trace_index -= 1
      when 'ArrowDown'
        @trace_index += 1
      when 'PageUp'
        @trace_index -= 10
      when 'PageDown'
        @trace_index += 10
      when 'Home'
        @trace_index = 0
      when 'End'
        @trace_index = last_index
      end

      @trace_index = 0 if @trace_index.negative?
      @trace_index = last_index if @trace_index > last_index

      true
    end
  end
end
