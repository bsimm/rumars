# frozen_string_literal: true

require_relative 'parser'

module RuMARS
  # This class stores the lines and meta information of Redcode for loops.
  # It's used by the parser to collect the Redcode instructions inside a
  # for loop definition and will later unroll the loop(s) and inject it
  # into the parsing process again. During unroll, the loop variable name
  # is replaced by the current loop counter.
  class ForLoop
    # @param [String] expression_str an expression that can be resolved to
    #        an integer number representing the loop repeat count
    # @param [String] loop_var_name a String that is replaced with
    #        the current loop index + 1 when found in the form of
    #        &<loop_var_name>.
    def initialize(constants, expression_str, loop_var_name = nil)
      @constants = constants
      @expression_str = expression_str
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
    def unroll(outer_loop_variables = {})
      lines = []
      olv = outer_loop_variables.clone

      resolve_expression(outer_loop_variables).times do |i|
        sub_lines = []
        olv[@loop_var_name] = i

        @lines.each do |line|
          # Recurse to expend nested loops
          if line.respond_to?(:unroll)
            sub_lines += line.unroll(olv)
          else
            sub_lines << line
          end
        end

        sub_lines.each do |line|
          # Replace the constants in the line. This is necessary to allow
          # for constants to contain loop variable names that will be
          # replaced in the next step.
          @constants.each do |name, text|
            line.gsub!(/(?!=\w)#{name}(?!<=\w)/, text)
          end

          # Replace the '&<loop_var_name>' strings with the respective repeat counters.
          olv.each do |name, value|
            line = replace_loop_var_name_with_index(line, name, value)
          end

          lines << line
        end
      end

      lines
    end

    private

    def replace_loop_var_name_with_index(text, loop_var_name, counter)
      text.gsub(Regexp.new("&#{loop_var_name}(?!<=\w)"), format('%02d', counter + 1))
          .gsub(Regexp.new("(?!<=\W)#{loop_var_name}(?!<=\w)"), (counter + 1).to_s)
    end

    def resolve_expression(outer_loop_variables)
      str = @expression_str

      outer_loop_variables.each do |name, value|
        str = replace_loop_var_name_with_index(str, name, value)
      end

      parser = Parser.new({})
      expression = parser.parse(str, :expr)

      expression.eval(@constants)
    end
  end
end
