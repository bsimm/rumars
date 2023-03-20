# frozen_string_literal: true

require_relative '../lib/rumars/parser'

RSpec.describe RuMARS::Parser do
  it 'should parse a simple program' do
    parser = RuMARS::Parser.new
    prog = <<~PRG
      ;redcode-94
          mov 0, 1
          end
    PRG
    program = parser.parse(prog)
    expect(program.instructions.size).to eql(1)
  end

  it 'should parse a program with constants' do
    parser = RuMARS::Parser.new
    prog = <<~PRG
      ;redcode-94
      one    equ #1
             mov 0, one
             end
    PRG
    program = parser.parse(prog)
    expect(program.instructions.size).to eql(1)
  end

  it 'should parse a program with expressions' do
    parser = RuMARS::Parser.new
    prog = <<~PRG
      ;redcode-94
             org start
      one    equ #1
      two    equ one + 1
             mov 0, two + 4
             add 1+3*4, 1+(3*4)
      start  sub 1*3-4, (1-3)*4
             end
    PRG
    program = parser.parse(prog)
    expect(program.instructions.size).to eql(3)
    expect(program.start_address).to eql(2)
    expect(program.instructions[0].b_operand.number).to eql(6)
    expect(program.instructions[1].a_operand.number).to eql(13)
    expect(program.instructions[1].b_operand.number).to eql(13)
    expect(program.instructions[2].a_operand.number).to eql(-1)
    expect(program.instructions[2].b_operand.number).to eql(-8)
  end
end
