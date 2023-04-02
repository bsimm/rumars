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
  end
end
