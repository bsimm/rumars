# frozen_string_literal: true

module RuMARS
  # This class stores the lines and meta information of Redcode for loops.
  # It's used by the parser to collect the Redcode instructions inside a
  # for loop definition and will later unroll the loop(s) and inject it
  # into the parsing process again. During unroll, the loop variable name
  # is replaced by the current loop counter.
  class ForLoop
    def initialize(repeats, loop_var_name = nil)
      @repeats = repeats
      @loop_var_name = loop_var_name

      # This can be ordinary lines (String) or nested loops (ForLoop) entries.
      @lines = []
    end

    # param [String or ForLoop] line
    def add_line(line)
      @lines << line
    end

    # Unroll the loop including all nested loops. This method calls itself
    # recursively if needed to expend nested loops.
    def unroll
      lines = []
      @repeats.times do |i|
        sub_lines = []
        @lines.each do |line|
          if line.respond_to?(:unroll)
            sub_lines += line.unroll
          else
            sub_lines << line
          end
        end

        sub_lines.each do |line|
          # Replace the '&<loop_var_name>' strings with the current repeat counter i + 1.
          lines << line.gsub(Regexp.new("&#{@loop_var_name}(?!<=\w)"), '%02d' % (i + 1))
        end
      end

      lines
    end
  end
end
