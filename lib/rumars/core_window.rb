# frozen_string_literal: true

require_relative 'textwm/window'
require_relative 'format'

module RuMARS
  class CoreWindow < TextWM::Window
    attr_accessor :show_address

    include Format

    def initialize(textwm, mars)
      super(textwm, 'Core Window')
      @mars = mars
      @show_address = nil
    end

    def update
      @virt_term.clear
      @virt_term.right_clip = @virt_term.bottom_clip = true

      current_warrior = @mars.console_window.current_warrior
      program_counters = @mars.scheduler.program_counters(current_warrior)
      breakpoints = @mars.scheduler.breakpoints
      find_start_address

      (@height - 2).times do |i|
        address = MemoryCore.fold(@show_address + i)
        breakpoint = breakpoints.include?(address) ? '*' : ' '
        pc = program_counters.include?(address) ? '>' : ' '
        puts " #{aformat(address)}#{breakpoint}#{pc} " \
             "#{format('%-16s', current_warrior&.resolve_address(address) || '')} " \
             "#{@mars.memory_core.instruction(address)}"
      end

      super
    end

    def getch(char)
      case char
      when 'ArrowUp'
        change_show_address(-1)
      when 'ArrowDown'
        change_show_address(1)
      when 'PageUp'
        change_show_address(-(@height - 2))
      when 'PageDown'
        change_show_address(@height - 2)
      end

      true
    end

    private

    def change_show_address(delta)
      @show_address = MemoryCore.fold(find_start_address + delta)
    end

    def find_start_address
      return @show_address if @show_address

      current_warrior = @mars.current_warrior
      program_counters = @mars.scheduler.program_counters(current_warrior)
      current_pc = program_counters&.first || 0

      @show_address = MemoryCore.fold(current_pc - (@height / 3))
    end

  end
end
