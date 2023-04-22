#
# Copyright (c) Chris Schlaeger <cs@taskjuggler.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#
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
      vertical_scrollbar.enable(true)
    end

    def update
      @virt_term.clear
      @virt_term.right_clip = @virt_term.bottom_clip = true
      t = @textwm.terminal

      current_warrior = @mars.console_window.current_warrior
      program_counters = @mars.scheduler.program_counters(current_warrior)
      breakpoints = @mars.scheduler.breakpoints
      find_start_address

      (@height - 2).times do |i|
        address = MemoryCore.fold(@show_address + i)
        breakpoint = breakpoints.include?(address) ? '*' : ' '
        pc = program_counters.include?(address) ? '>' : ' '
        instruction = @mars.memory_core.peek(address)
        line = "#{instruction.pid}:#{aformat(address)}#{breakpoint}#{pc} " \
               "#{format('%-16s', current_warrior&.resolve_address(address) || '')} " \
               "#{instruction}"
        line += ' ' * (@width - 2 - line.length) if line.length < @width

        if program_counters.first == address
          puts "#{t.ansi_code(:reverse)}#{line}#{t.ansi_code(:attributes_off)}"
        else
          puts line
        end
      end

      super
    end

    def update_vertical_scrollbar
      vertical_scrollbar.update(@height - 2, MemoryCore.size, @height - 2, @show_address)
    end

    def getch(char)
      case char
      when 'Home'
        # The Home key moves the window content to show the current PC
        current_warrior = @mars.current_warrior
        program_counters = @mars.scheduler.program_counters(current_warrior)
        @show_address = program_counters.first || 0
      when 'End'
        # The end key moves the window content to show 0 at the center
        @show_address = 0 - (@height / 2)
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
