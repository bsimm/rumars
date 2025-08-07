#
# Copyright (c) Chris Schlaeger <cs@taskjuggler.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#
# frozen_string_literal: true

require_relative 'textwm/window'

module RuMARS
  class WarriorsWindow < TextWM::Window
    attr_accessor :round, :cycle

    def initialize(textwm, mars)
      super(textwm, 'Warriors Window')
      @mars = mars
      vertical_scrollbar.enable(true)

      @round = 0
      @cycle = 0

      @text_color = :brightwhite
      @background_color = :black
    end

    def update
      @virt_term.clear
      @virt_term.right_clip = @virt_term.bottom_clip = true

      puts "Round: #{@round + 1}"
      puts "Cycle: #{@cycle + 1}"
      puts

      scoreboard
      leaderboard

      super
    end

    private

    def scoreboard
      warriors = @mars.warriors.sort { |w1, w2| w2.score <=> w1.score }
      warriors.each do |warrior|
        puts "Name:  #{colored_name(warrior)}"
        if warrior.program
          puts "Score: #{warrior.score}"
          puts "Kills: #{warrior.kills}"
          puts "Hits:  #{warrior.hits}"
          puts "Lifes: #{warrior.task_queue.length}"
        else
          puts "Disqualified"
        end
        puts
      end
      puts
    end

    def leaderboard
      warriors = @mars.warriors.sort { |w1, w2| w2.wins <=> w1.wins }
      puts 'Leaderboard'
      place = 0
      previous_wins = -1
      warriors.each do |warrior|
        next unless warrior.program

        place += 1 if previous_wins != warrior.wins
        puts "#{place}. #{colored_name(warrior)} #{warrior.wins}"
      end
    end

    def colored_name(warrior)
      t = @textwm.terminal
      if warrior.program
        fg_color = TextWM::Terminal::FGCOLORS.keys[8 + warrior.pid]
        "#{t.ansi_code(:color, fg_color, @background_color)}" \
          "#{warrior.name}#{t.ansi_code(:color, @text_color, @background_color)}"
      else
        warrior.name
      end
    end
  end
end
