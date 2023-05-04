#
# Copyright (c) Chris Schlaeger <cs@taskjuggler.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#
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
    # If a line that matches this regexp is present, the parsing will only
    # start after this line.
    REDCODE_MARKER_REGEXP = /^;redcode(-94|-x|)\s*.*$/

    # This class handles all parsing errors.
    class ParseError < RuntimeError
      def initialize(parser, message, line_no = nil)
        super()
        @parser = parser
        @message = message
        @line_no = line_no
      end

      def to_s
        s = +"#{@parser.file_name ? "#{@parser.file_name}: " : ''}#{@line_no || @parser.line_no}: #{@message}\n  "

        unless @parser.scanner.eos?
          s += "#{@parser.scanner.string}\n  " \
               "#{' ' * @parser.scanner.pos}^"
        end

        s
      end
    end

    attr_reader :file_name, :line_no, :scanner, :constants

    def initialize(settings, logger = $stdout)
      @logger = logger
      @line_no = 0
      @file_name = nil
      @scanner = nil
      @last_equ_label = nil
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
        val_str = value.to_s
        case name
        when :max_processes
          @constants['MAXPROCESSES'] = val_str
        when :max_cycles
          @constants['MAXCYCLES'] = val_str
        when :max_length
          @constants['MAXLENGTH'] = val_str
        when :min_distance
          @constants['MINDISTANCE'] = val_str
        when :read_limit
          @constants['READLIMIT'] = val_str
        when :write_limit
          @constants['WRITELIMIT'] = val_str
        end
      end
    end

    def preprocess_and_parse(source_code)
      @program = Program.new

      @ignore_lines = false
      buffer_lines = []
      preprocess(source_code).each do |line_no, line|
        @line_no = line_no

        # @ignore_lines is set to true when we found the 'end' instruction.
        next if @ignore_lines

        # Set the CURLINE constant to the number of already read instructions
        @constants['CURLINE'] = @program.instructions.length.to_s

        loop do
          line = expand_constants(line, buffer_lines)

          parse(line, :comment_or_instruction)

          break unless (line = buffer_lines.shift)
        end
      end

      begin
        @program.evaluate_expressions
      rescue Expression::ExpressionError => e
        @program = nil
        raise ParseError.new(self, "Error in expression: #{e.message}", e.line_no)
      end

      @program
    end

    def parse(text, entry_token)
      @scanner = StringScanner.new(text)
      ast = send(entry_token)

      raise ParseError.new(self, 'Unknown token found') unless @scanner.eos?

      ast
    end

    private

    # The preprocessor does the initial processing of the Redcode file. It removes
    # header (before ;redcode line) and tail (after END) sections. It scans for EQU
    # instructions and replaces them when found after the declaration. It also
    # expands FOR/ROF loops. Tabulator signs will be replaced with a space character
    # and non-ASCII characters will be eliminated.
    # @return [Array] List of lines. Each line is an 2 field Array of original line
    #         number and the line.
    def preprocess(source_code)
      @line_no = 0

      # Check if we have a redcode start marker.
      ignore_lines = !(REDCODE_MARKER_REGEXP =~ source_code).nil?

      processed_lines = []
      buffer_lines = []

      source_code.lines.each do |line|
        # Replace TABs with a space
        line.gsub!(/\t/, ' ')
        # Remove all non-visible and non ASCII characters
        line.gsub!(/[^ -~]/, '')

        # If we detect the redcode start marker, we start parsing.
        ignore_lines = false if REDCODE_MARKER_REGEXP =~ line

        @line_no += 1

        # Ignore empty lines
        next if ignore_lines || /\A\s*\z/ =~ line

        next unless (line = collect_for_loops(line, buffer_lines))

        loop do
          line = expand_constants(line, buffer_lines)

          @scanner = StringScanner.new(line)
          unless label_equ_or_for_instruction
            processed_lines << [@line_no, line]
            @last_equ_label = nil
          end

          break unless (line = buffer_lines.shift)
        end
      end

      processed_lines
    end

    def collect_for_loops(line, buffer_lines)
      if (current_loop = @for_loops.last)
        if /^\s*rof\s*(|;.*)$/i =~ line
          @for_loops.pop
        elsif (fl = /^([a-z_][a-z0-9_]*)\s+for\s+(.+)$/i.match(line))
          # For loop with loop variable
          new_loop = ForLoop.new(@constants, fl[2], fl[1])
          @for_loops.push(new_loop)
          current_loop.add_line(new_loop)
        elsif (fl = /^\s*for\s+(.+)$/i.match(line))
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

    def expand_constants(line, buffer_lines)
      @constants.each do |name, text|
        line.gsub!(/(?<!\w)#{name}(?!\w)/, text)
      end

      # Check if the EQU span multiple lines. If not, just return the expanded
      # line.
      return line if (lines = line.split("\n")).length == 1

      # For multiple lines, the first line becomes the current line.
      line = lines.shift
      # The other lines will be prepended to the buffer_lines buffer.
      lines.reverse.each do |ln|
        buffer_lines.unshift(ln)
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

    def identifier
      scan(/[A-Za-z_][A-Za-z0-9_]*/)
    end

    def equ
      scan(/EQU(?=[^\w])/i)
    end

    def for_token
      scan(/FOR(?=[^\w])/i)
    end

    def rof
      scan(/ROF(?=([^\w]|$))/i)
    end

    def end_token
      scan(/END(?=([^\w]|$))/i)
    end

    def org
      scan(/ORG(?=[^\w])/i)
    end

    def not_comment
      scan(/[^;\n]+/)
    end

    def opcode
      scan(/(ADD|CMP|DAT|DIV|DJN|JMN|JMP|JMZ|MOD|MOV|MUL|NOP|SEQ|SNE|SLT|SPL|SUB)(?=[. ])/i)
    end

    def mode
      scan(/[#@*<>{}$]/) || '$'
    end

    def modifier
      scan(/\.(AB|BA|A|B|F|X|I)/i)
    end

    def number
      scan(/[0-9]+/)
    end

    #
    # Grammar
    #
    def comment_or_instruction
      (comment || instruction_line)
    end

    def comment
      space && (s = semicolon) && (text = anything)

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

    def instruction_line(prev_label = nil)
      return true if pseudo_or_instruction(prev_label)

      @program.add_label(prev_label) if prev_label

      if (label = optional_label) && !instruction_line(label)
        # Line with just a label. It references the next instruction.
        @program.add_label(label)
        # There may be a comment after the label
        return optional_comment
      end

      nil
    end

    def pseudo_or_instruction(label)
      space && (end_instruction(label) || org_instruction(label) ||
        instruction(label)) && space && optional_comment
    end

    def label_equ_or_for_instruction(prev_label = nil)
      return true if equ_or_for_instruction(prev_label)

      @program.add_label(prev_label) if prev_label

      (label = optional_label) && label_equ_or_for_instruction(label)
    end

    def equ_or_for_instruction(label)
      space && (for_instruction(label) || equ_instruction(label)) && space && optional_comment
    end

    def equ_instruction(label)
      (e = equ) && space && (definition = not_comment)

      return nil unless e

      unless label
        raise ParseError.new(self, 'EQU lines must have a label') unless @last_equ_label

        # We have a multi-line EQU statement. We'll just append the line to the
        # definition in the last line.
        @constants[@last_equ_label] += "\n" + definition

        return true
      end

      raise ParseError.new(self, "Constant #{label} has already been defined") if @constants.include?(label)

      @last_equ_label = label
      @constants[label] = definition

      true
    end

    def for_instruction(label)
      (f = for_token) && space && (repeats = not_comment)

      return nil unless f

      raise ParseError.new(self, 'for loop must have a fixed repeat count') unless repeats

      @last_equ_label = nil

      @for_loops << ForLoop.new(@constants, repeats, label)

      true
    end

    def org_instruction(label)
      (o = org) && space && (exp = expr)

      return nil unless o

      raise ParseError.new(self, 'Expression expected') unless exp

      @program.add_label(label) if label
      @program.start_address = exp

      true
    end

    def end_instruction(label)
      (e = end_token) && space && (exp = expr)

      return nil unless e

      @program.add_label(label) if label
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

      if e2.nil?
        if opc == 'DAT'
          # If the DAT instruction has only one operand, it will be the B operand.
          # The A operand will be 0.
          e2 = e1
          e1 = Operand.new('#', Expression.new(0, nil, nil, @line_no))
        elsif %w[JMP SPL NOP].include?(opc)
          # These instructions may have only 1 operand. In that case the B
          # operand defaults to 0.
          e2 = Operand.new('#', Expression.new(0, nil, nil, @line_no))
        else
          # All other instructions must always have 2 operands.
          raise ParseError.new(self, "The #{opc} instruction must have 2 operands")
        end
      end
      mod = default_modifier(opc, e1, e2) if mod == ''

      Instruction.new(0, opc, mod, e1, e2)
    end

    def instruction(label)
      return nil unless (instruction = opcode_and_operands)

      @program.add_label(label) if label
      @program.append_instruction(instruction)

      true
    end

    def optional_label
      (l = identifier) && colon

      l || nil
    end

    def optional_modifier
      modifier || '.'
    end

    def optional_expression
      comma && space && expression
    end

    def expression
      (m = mode) && space && (e = expr)
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
          ex = Expression.new(t1, optr, node.operand1, @line_no)
          node.operand1 = ex
          t2
        else
          Expression.new(t1, optr, t2, @line_no)
        end
      else
        t1
      end
    end

    def term
      signed_term || unsigned_term
    end

    def unsigned_term
      t = (identifier || ((n = number) && n.to_i) || parenthesized_expression)

      return nil unless t

      # Protect the expression in parenthesis from being broken up by
      # the precedence evaluation.
      t.parenthesis = true if t.is_a?(Expression)

      Expression.new(t, nil, nil, @line_no)
    end

    def signed_term
      (s = sign_prefix) && (t = term)

      return nil unless s

      raise ParseError.new(self, 'Sign prefix must be followed by a term') unless t

      s == '-' ? Expression.new(t, s, nil, @line_no) : t
    end

    def parenthesized_expression
      (op = open_parenthesis) && space && (e = expr) && space && (cp = close_parenthesis)

      return nil unless op

      raise ParseError.new(self, 'Expression expected') unless e

      raise ParseError.new(self, "')' expected") unless cp

      e
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
