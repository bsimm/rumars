# frozen_string_literal: true

require 'strscan'

require_relative 'program'
require_relative 'instruction'

# REDCODE 94 Syntax definition
#
# Taken from http://www.koth.org/info/icws94.html
#
# assembly_file:
#         list
# list:
#         line | line list
# line:
#         comment | instruction
# comment:
#         ; v* EOL | EOL
# instruction:
#         label_list operation mode field comment |
#         label_list operation mode expr , mode expr comment
# label_list:
#         label | label label_list | label newline label_list | e
# label:
#         alpha alphanumeral*
# operation:
#         opcode | opcode.modifier
# opcode:
#         DAT | MOV | ADD | SUB | MUL | DIV | MOD |
#         JMP | JMZ | JMN | DJN | CMP | SLT | SPL |
#         ORG | EQU | END
# modifier:
#         A | B | AB | BA | F | X | I
# mode:
#         # | $ | @ | < | > | e
# expr:
#         term |
#         term + expr | term - expr |
#         term * expr | term / expr |
#         term % expr
# term:
#         label | number | (expression)
# number:
#         whole_number | signed_integer
# signed_integer:
#         +whole_number | -whole_number
# whole_number:
#         numeral+
# alpha:
#         A-Z | a-z | _
# numeral:
#         0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9
# alphanumeral:
#         alpha | numeral
# v:
#         ^EOL
# EOL:
#         newline | EOF
# newline:
#         LF | CR | LF CR | CR LF
# e:

module RuMARS
  # REDCODE parser
  class Parser
    # This class handles all parsing errors.
    class ParseError < RuntimeError
      def initialize(parser, message)
        super()
        @parser = parser
        @message = message
      end

      def to_s
        "#{@parser.file_name ? "#{@parser.file_name}: " : ''}#{@parser.line_no}: #{@message}'\n" \
          "  #{@parser.scanner.string}\n" \
          "  #{' ' * @parser.scanner.pos}^"
      end
    end

    attr_reader :file_name, :line_no, :scanner

    def initialize
      @line_no = 0
      @file_name = nil
      @scanner = nil
    end

    def parse(source_code)
      program = Program.new

      @line_no = 1
      source_code.lines.each do |line|
        @scanner = StringScanner.new(line)
        c_or_i = comment_or_instruction
        program.append_instruction(c_or_i) if c_or_i.is_a?(Instruction)

        @line_no += 1
      end

      program
    end

    private

    def scan(regexp)
      # puts "Scanning '#{@scanner.string[@scanner.pos..]} with #{regexp}"
      @scanner.scan(regexp)
    end

    #
    # Terminal Tokens
    #
    def space
      scan(/\s*/) || ''
    end

    def eol
      scan(/\r/)
    end

    def semicolon
      scan(/;/)
    end

    def comma
      scan(/,/)
    end

    def sign_prefix
      scan(/[+-]/)
    end

    def anything_but_eol
      scan(/[^\r]/)
    end

    def opcode
      scan(/(DAT|MOV|ADD|JMP)/)
    end

    def mode
      scan(/[#@<>e$]/) || '$'
    end

    def modifier
      scan(/\.(AB|BA|A|B|F|X|I)/)
    end

    def number
      scan(/[0-9]+/).to_i
    end

    #
    # Grammar
    #
    def comment_or_instruction
      (comment || (ins = instruction)) && eol

      ins
    end

    def comment
      semicolon && anything_but_eol
    end

    def instruction
      space && (opc = opcode) && (mod = optional_modifier[1..]) && space && (e1 = expression) &&
        space && (e2 = optional_expression) && space

      raise ParseError.new(self, 'Uknown instruction') unless opc

      raise ParseError.new(self, "Instruction #{opc} must have an A-operand") unless e1

      # The default B-operand is an immediate value of 0
      e2 ||= Operand.new('#', 0)
      mod = default_modifier(opc, e1, e2) if mod == ''
      Instruction.new(0, opc, mod, e1, e2)
    end

    def optional_modifier
      modifier || '.'
    end

    def optional_expression
      comma && space && expression
    end

    def expression
      Operand.new(mode, signed_number || number)
    end

    def signed_number
      (sign = sign_prefix) && (n = number)
      sign == '-' ? -n : n
    end

    #
    # Utility methods
    #
    def default_modifier(opc, e1, e2)
      case opc
      when 'DAT'
        return 'F' if '#$@<>'.include?(e1.address_mode) && '#$@<>'.include?(e2.address_mode)
      when 'MOV', 'CMP'
        return 'AB' if e1.address_mode == '#' && '#$@<>'.include?(e2.address_mode)
        return 'B' if '$@<>'.include?(e1.address_mode) && e2.address_mode == '#'
        return 'I' if '$@<>'.include?(e1.address_mode) && '$@<>'.include?(e2.address_mode)
      when 'ADD', 'SUB', 'MUL', 'DIV', 'MOD'
        return 'AB' if e1.address_mode == '#' && '#$@<>'.include?(e2.address_mode)
        return 'B' if '$@<>'.include?(e1.address_mode) && e2.address_mode == '#'
        return 'F' if '$@<>'.include?(e1.address_mode) && '$@<>'.include?(e2.address_mode)
      when 'SLT'
        return 'AB' if e1.address_mode == '#' && '#$@<>'.include?(e2.address_mode)
        return 'B' if '$@<>'.include?(e1.address_mode) && '#$@<>'.include?(e2.address_mode)
      when 'JMP', 'JMZ', 'JMN', 'DJN', 'SPL'
        return 'B' if '#$@<>'.include?(e1.address_mode) && '#$@<>'.include?(e2.address_mode)
      else
        raise ParseError.new(self, "Unknown instruction #{opc}")
      end

      raise ParseError.new(self, "Cannot determine default modifier for #{opc} #{e1}, #{e2}")
    end
  end
end
