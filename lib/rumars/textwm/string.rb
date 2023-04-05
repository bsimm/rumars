# Extend the standard Ruby String class to include a method to calculate the
# length of the visible characters ignoring ANSI escape sequences.
class String
  # This regular expression matches all VT100 escape sequences.
  #ESCAPE_SEQUENCE_REGEXP = Regexp.new("\033((\\[((\\d+;)*\\d+)?[A-DHJKMRcf-ilmnprsu])|\\(|\\))")
  ESCAPE_SEQUENCE_REGEXP = Regexp.new("\033(?:[@-Z\\-_]|\\[[0-?]*[ -/]*[@-~])")

  def visible_length
    # Eliminate all VT100 escape sequences from the String and determine the length.
    gsub(ESCAPE_SEQUENCE_REGEXP, '').length
  end

  # Return the first N visible characters including the invisible characters
  # leading up to that character.
  def first_visible_characters(number)
    visible_char_counter = 0
    str = clone
    cut_str = +''

    until str.empty?
      c = str[0]
      if c == "\e"
        # We have found an escape sequence. Use the Regexp to cut it from
        # the string.
        escape_sequence = str.match(String::ESCAPE_SEQUENCE_REGEXP)[0]
        cut_str += escape_sequence
        str = str[escape_sequence.length..]
      else
        # Normal (visible) characters can just be appended and the
        # counter will be increased by one.
        cut_str += c
        str = str[1..]
        visible_char_counter += 1
      end

      break if visible_char_counter >= number
    end

    cut_str
  end
end
