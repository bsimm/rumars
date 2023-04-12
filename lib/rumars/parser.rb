# frozen_string_literal: true

require 'strscan'

require_relative 'settings'
require_relative 'program'
require_relative 'instruction'
require_relative 'expression'
require_relative 'for_loop'

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
        "#{@parser.file_name ? "#{@parser.file_name}: " : ''}#{@parser.line_no}: #{@message}'\n  " \
          "#{@parser.scanner.string}\n  " \
          "#{' ' * @parser.scanner.pos}^"
      end
    end

    attr_reader :file_name, :line_no, :scanner, :constants

    def initialize(settings, logger = $stdout)
      @logger = logger
      @line_no = 0
      @file_name = nil
      @scanner = nil
      @for_loops = []
      # Hash to store the EQU definitions
      @constants = {
        'CORESIZE' => MemoryCore.size.to_s,
        'PSPACESIZE' => '0',
        'VERSION' => '100',
        'WARRIORS' => '1'
      }
      # Set other constants based on the MARS settings
      settings.each_pair do |name, value|
        case name
        when :max_processes
          @constants['MAXPROCESSES'] = value.to_s
        when :max_cycles
          @constants['MAXCYCLES'] = value.to_s
        when :max_length
          @constants['MAXLENGTH'] = value.to_s
        when :min_distance
          @constants['MINDISTANCE'] = value.to_s
        end
      end
    end

    def preprocess_and_parse(source_code)
      @program = Program.new

      @line_no = 1
      @ignore_lines = true
      buffer_lines = []
      source_code.lines.each do |line|
        # Remove trailing line break
        line.chop!

        # Redcode files require a line that reads
        # ;redcode-94
        # All lines before this line will be ignored.
        @ignore_lines = false if /^;redcode(-94|)\s*$/ =~ line

        @line_no += 1

        # Ignore empty lines
        next if @ignore_lines || /\A\s*\z/ =~ line

        next unless (line = collect_for_loops(line, buffer_lines))

        loop do
          # Set the CURLINE constant to the number of already read instructions
          @constants['CURLINE'] = @program.instructions.length.to_s

          @constants.each do |name, text|
            line.gsub!(/(?!=\w)#{name}(?!<=\w)/, text)
          end

          parse(line, :comment_or_instruction)

          break unless (line = buffer_lines.shift)
        end
      end

      begin
        @program.evaluate_expressions
      rescue Expression::ExpressionError => e
        raise ParseError.new(self, "Error in expression: #{e.message}")
        @program = nil
      end

      @program
    end

    def parse(text, entry_token)
      @scanner = StringScanner.new(text)
      send(entry_token)
    end

    private

    def collect_for_loops(line, buffer_lines)
      if (current_loop = @for_loops.last)
        if /^\s*rof\s*(|;.*)$/ =~ line
          @for_loops.pop
        elsif (fl = /^([A-Za-z_][A-Za-z0-9_]*)\s+for\s+(.+)$/.match(line))
          # For loop with loop variable
          new_loop = ForLoop.new(@constants, fl[2], fl[1])
          @for_loops.push(new_loop)
          current_loop.add_line(new_loop)
        elsif (fl = /^\s*for\s+(.+)$/.match(line))
          # For loop without loop variable
          new_loop = ForLoop.new(@constants, fl[1])
          @for_loops.push(new_loop)
          current_loop.add_line(new_loop)
        else
          current_loop.add_line(line)
        end

        return nil unless @for_loops.empty?

        buffer_lines.concat(current_loop.unroll)

        line = buffer_lines.shift
      end

      line
    end

    def scan(regexp)
      # @logger.puts "Scanning '#{@scanner.string[@scanner.pos..]}' with #{regexp}"
      @scanner.scan(regexp)
    end

    #
    # Terminal Tokens
    #
    def space
      scan(/\s*/) || ''
    end

    def semicolon
      scan(/;/)
    end

    def comma
      scan(/,/)
    end

    def colon
      scan(/:/)
    end

    def operator
      scan(%r{(-|\+|\*|/|%|==|!=|<=|>=|<|>|&&|\|\|)})
    end

    def open_parenthesis
      scan(/\(/)
    end

    def close_parenthesis
      scan(/\)/)
    end

    def sign_prefix
      scan(/[+-]/)
    end

    def anything
      scan(/.*$/)
    end

    def label
      scan(/[A-Za-z_][A-Za-z0-9_]*/)
    end

    def equ
      scan(/EQU/i)
    end

    def for_token
      scan(/FOR/i)
    end

    def rof
      scan(/ROF/i)
    end

    def end_token
      scan(/END/i)
    end

    def org
      scan(/ORG/i)
    end

    def not_comment
      scan(/[^;\n]+/)
    end

    def opcode
      scan(/(ADD|CMP|DAT|DIV|DJN|JMN|JMP|JMZ|MOD|MOV|MUL|NOP|SEQ|SNE|SLT|SPL|SUB)/i)
    end

    def mode
      scan(/[#@*<>{}$]/) || '$'
    end

    def modifier
      scan(/\.(AB|BA|A|B|F|X|I)/i)
    end

    def whole_number
      scan(/[0-9]+/)
    end

    #
    # Grammar
    #
    def comment_or_instruction
      (comment || instruction_line)
    end

    def comment
      (s = semicolon) && (text = anything)

      return nil unless s

      if text.start_with?('name ')
        @program.name = text[5..].strip
      elsif text.start_with?('author ')
        @program.author = text[7..].strip
      elsif text.start_with?('strategy ')
        @program.add_strategy(text[9..])
      elsif text.start_with?('assert ')
        assert = text[7..].strip
        parser = Parser.new({}, @logger)
        expression = parser.parse(assert, :expr)

        raise ParseError.new(self, "Assert failed: #{expression}") unless expression.eval(@constants) == 1
      end

      ''
    end

    def instruction_line
      (label = optional_label) && space && (poi = pseudo_or_instruction(label)) && space && optional_comment

      # Lines that only have a label are labels for the line with the next instruction.
      @program.add_label(label) if poi == 'label_line' && !label.empty?
    end

    def pseudo_or_instruction(label)
      equ_instruction(label) || for_instruction(label) || end_instruction || org_instruction || instruction(label) || 'label_line'
    end

    def equ_instruction(label)
      (e = equ) && space && (definition = not_comment)

      return nil unless e

      raise ParseError.new(self, 'EQU lines must have a label') if label.empty?

      raise ParseError.new(self, "Constant #{label} has already been defined") if @constants.include?(label)

      @constants[label] = definition
    end

    def for_instruction(label)
      (f = for_token) && space && (repeats = not_comment)

      return nil unless f

      raise ParseError.new(self, 'for loop must have a fixed repeat count') unless repeats

      @for_loops << ForLoop.new(@constants, repeats, label)

      true
    end

    def org_instruction
      (o = org) && space && (exp = expr)

      return nil unless o

      raise ParseError.new(self, 'Expression expected') unless exp

      @program.start_address = exp
    end

    def end_instruction
      (e = end_token) && space && (exp = expr)

      return nil unless e

      # Older Redcode standards used the END instruction to set the program start address
      @program.start_address = exp if exp

      @ignore_lines = true
    end

    def opcode_and_operands
      (opc = opcode) && (mod = optional_modifier[1..]) &&
        space && (e1 = expression) && space && (e2 = optional_expression) && space && optional_comment

      return nil unless opc

      # Redcode instructions are case-insensitive. We use upper case internally,
      # but allow for lower-case notation in source files.
      opc.upcase!
      mod.upcase!

      raise ParseError.new(self, "Instruction #{opc} must have an A-operand") unless e1

      # The default B-operand is an immediate value of 0
      e2 ||= Operand.new('#', Expression.new(0, nil, nil))
      mod = default_modifier(opc, e1, e2) if mod == ''

      Instruction.new(0, opc, mod, e1, e2)
    end

    def instruction(label)
      return nil unless (instruction = opcode_and_operands)

      @program.add_label(label) unless label.empty?
      @program.append_instruction(instruction)
    end

    def optional_label
      (l = label) && colon

      l || ''
    end

    def optional_modifier
      modifier || '.'
    end

    def optional_expression
      comma && space && expression
    end

    def expression
      (m = mode) && (e = expr)
      raise ParseError.new(self, 'Expression expected') unless e

      Operand.new(m, e)
    end

    def expr
      (t1 = term) && space && (optr = operator) && space && (t2 = expr)

      if optr
        raise ParseError.new(self, 'Right hand side of expression is missing') unless t2

        # Eliminate needless unary expression.
        t1 = t1.operand1 unless t1.nil? || t1.operator

        if t2.respond_to?(:find_lhs_node) && (node = t2.find_lhs_node(optr))
          ex = Expression.new(t1, optr, node.operand1)
          node.operand1 = ex
          t2
        else
          Expression.new(t1, optr, t2)
        end
      else
        t1
      end
    end

    def term
      t = (label || number || parenthesized_expression)

      return nil unless t

      # Protect the expression in parenthesis from being broken up by
      # the precedence evaluation.
      t.parenthesis = true if t.is_a?(Expression)

      Expression.new(t, nil, nil)
    end

    def parenthesized_expression
      (op = open_parenthesis) && space && (e = expr) && space && (cp = close_parenthesis)

      return nil unless op

      raise ParseError.new(self, 'Expression expected') unless e

      raise ParseError.new(self, "')' expected") unless cp

      e
    end

    def number
      (s = signed_number) || (n = whole_number)

      return s if s

      n ? n.to_i : nil
    end

    def signed_number
      (sign = sign_prefix) && (n = whole_number)
      return nil unless sign

      sign == '-' ? -(n.to_i) : n.to_i
    end

    def optional_comment
      comment || ''
    end

    #
    # Utility methods
    #
    def default_modifier(opc, e1, e2)
      case opc
      when 'ORG', 'END'
        return ''
      when 'DAT', 'NOP'
        return 'F'
      when 'MOV', 'CMP'
        return 'AB' if e1.address_mode == '#' && '#$@*<>{}'.include?(e2.address_mode)
        return 'B' if '$@*<>{}'.include?(e1.address_mode) && e2.address_mode == '#'
        return 'I'
      when 'ADD', 'SUB', 'MUL', 'DIV', 'MOD'
        return 'AB' if e1.address_mode == '#' && '#$@*<>{}'.include?(e2.address_mode)
        return 'B' if '$@*<>{}'.include?(e1.address_mode) && e2.address_mode == '#'
        return 'F'
      when 'SLT'
        return 'AB' if e1.address_mode == '#' && '#$@*<>{}'.include?(e2.address_mode)
        return 'B'
      when 'JMP', 'JMZ', 'JMN', 'DJN', 'SPL'
        return 'B'
      when 'SEQ', 'SNE'
        return 'I'
      else
        raise ParseError.new(self, "Unknown instruction #{opc}")
      end

      raise ParseError.new(self, "Cannot determine default modifier for #{opc} #{e1}, #{e2}")
    end
  end
end
