#
# Copyright (c) Chris Schlaeger <cs@taskjuggler.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#
# frozen_string_literal: true

module RuMARS
  module Format
    def aformat(address)
      if address
        format('%04d', address)
      else
        '    '
      end
    end

    def iformat(instruction)
      format('%-19s', instruction || '')
    end

    def aiformat(address_instruction)
      if address_instruction
        address = address_instruction[0]
        instruction = address_instruction[1] || ''
      else
        address = nil
        instruction = ''
      end

      "#{aformat(address)}: #{iformat(instruction)}"
    end

    def nformat(number)
      first_negative = MemoryCore.size / 2
      (number >= first_negative ? -(MemoryCore.size - number) : number).to_s
    end
  end
end
