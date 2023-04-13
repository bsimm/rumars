# frozen_string_literal: true

module TextWM
  class Scrollbar
    attr_reader :enabled

    def initialize(direction)
      @direction = direction
      @enabled = true
      @bar = nil
      @direction = nil
    end

    def enable(enabled)
      @enabled = enabled
    end

    def update(size, total_space, visible_space, position)
      @size = size
      @total_space = total_space

      @visible_space = visible_space
      position = total_space - visible_space if position > (total_space - visible_space)

      @position = position

      @bar = nil
    end

    def line(index)
      @bar ||= render_bar

      @bar[index]
    end

    def bar
      @bar ||= render_bar

      @bar
    end

    private

    def render_bar
      @bar = +''

      @bar += @position == 0 ? '▲' : '△'

      if @size > 2

        area_size = @size - 2

        if @total_space.zero?
          slider_size = area_size
          slider_start = 0
        else
          slider_size = (area_size * (@visible_space.to_f / @total_space)).ceil
          slider_size = 1 if slider_size < 1

          slider_start = (area_size * (@position.to_f / @total_space)).to_i
          slider_start = area_size - 1 if slider_start >= area_size
        end

        area_size.times do |i|
          @bar += slider_start <= i && i < slider_start + slider_size ? '▓' : '░'
        end
      end

      @bar += @position >= @total_space - @visible_space ? '▼' : '▽'

      @bar
    end
  end
end
