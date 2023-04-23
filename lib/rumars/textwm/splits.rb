#
# Copyright (c) Chris Schlaeger <cs@taskjuggler.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#
# frozen_string_literal: true

module TextWM
  class Splits
    DIRECTIONS = %i[vertical horizontal]

    attr_accessor :ratios

    def initialize(direction, *ratios)
      raise "Unknown direction #{direction}" unless DIRECTIONS.include?(direction)

      @direction = direction
      @ratios = ratios
      @splits_or_windows = []

      @col = @row = @width = @height = nil
    end

    def assign(index, split_or_window)
      raise "Index must be between 0 and #{@ratios.length - 1}" unless index >= 0 && index < @ratios.length

      @splits_or_windows[index] = split_or_window
    end

    def resize(col, row, width, height)
      @col = col
      @row = row

      # Sizes of Splits are calculated from outer to inner splits.
      if @direction == :horizontal
        calc_sizes(width, @ratios).each_with_index do |size, index|
          @splits_or_windows[index].resize(col, row, size, height)
          col += size
        end
      else
        calc_sizes(height, @ratios).each_with_index do |size, index|
          @splits_or_windows[index].resize(col, row, width, size)
          row += size
        end
      end
    end

    def visible?(index)
      (window = @splits_or_windows[index]).is_a?(Window) && window.visible?
    end

    private

    def calc_sizes(total, ratios)
      sizes = Array.new(ratios.length, 0)

      return sizes if total.zero?

      sum = 0
      flex_count = 0
      ratios.each_with_index do |ratio, index|
        case ratio
        when Float
          sizes[index] = (total * ratio).to_i
        when Integer
          sizes[index] = ratio
        else
          flex_count += 1
        end

        sum += sizes[index] if sizes[index]
      end

      # raise ArgumentError, "Can't fit #{sum} into #{total}" if sum > total

      return sizes if flex_count.zero? || sum > total

      flex_size = (total - sum) / flex_count
      remainder = flex_size % flex_count
      ratios.each_with_index do |ratio, index|
        next unless ratio.nil?

        sizes[index] = flex_size
        if remainder.positive?
          sizes[index] += 1
          remainder -= 1
        end
      end

      sizes
    end
  end
end
