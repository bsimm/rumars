# frozen_string_literal: true

require 'strscan'

require_relative 'program'
require_relative 'instruction'

# REDCODE 94 Syntax definition
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
    class Error < RuntimeError
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
      @scanner.scan(regexp)
    end

    #
    # Terminal Tokens
    #
    def space
      scan(/\s/) || ''
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

    def anything
      scan(/.*/)
    end

    def opcode
      scan(/(DAT|MOV)/)
    end

    def mode
      scan(/[#@<>e$]/) || '$'
    end

    def modifier
      scan(/\.(A|B|AB|BA|F|X|I)/)
    end

    def number
      scan(/[0-9]+/).to_i
    end

    #
    # Grammar
    #
    def comment_or_instruction
      comment || instruction
    end

    def comment
      semicolon && anything
    end

    def instruction
      (opc = opcode) && (mod = optional_modifier) && space && (e1 = expression) && space && (e2 = optional_expression) && space
      Instruction.new(0, opc, mod, e1, e2)
    end

    def optional_modifier
      modifier || 'F'
    end

    def optional_expression
      ex = nil
      (c = comma) && space && (ex = expression)
      raise Error.new(self, 'Comma missing') unless c

      ex
    end

    def expression
      Operand.new(mode, signed_number || number)
    end

    def signed_number
      (sign = sign_prefix) && (n = number)
      sign == '-' ? -n : n
    end
  end
end
