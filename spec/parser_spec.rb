# frozen_string_literal: true

require_relative '../lib/rumars/parser'

CORESIZE = 8000

RSpec.describe RuMARS::Parser do
  before(:all) do
    @settings = {
      core_size: 8000,
      max_length: 100,
      min_distance: 100
    }
  end

  it 'should parse a simple program' do
    parser = RuMARS::Parser.new(@settings)
    prog = <<~PRG
      ;redcode-94
          mov 0, 1
          end
    PRG
    program = parser.preprocess_and_parse(prog)
    expect(program.instructions.size).to eql(1)
  end

  it 'should parse a program with constants' do
    parser = RuMARS::Parser.new(@settings)
    prog = <<~PRG
      one    equ #1
             mov 0, one
             end
    PRG
    program = parser.preprocess_and_parse(prog)
    expect(program.instructions.size).to eql(1)
  end

  it 'should properly handle operator precedence' do
    parser = RuMARS::Parser.new(@settings)
    prog = <<~PRG
      mov 1+2+3+4, 4-3-2-1
      mov 1+2+3*4*5+6+7, 7-6-5*4*3-2-1
      mov 1-2+3-4+5-6, 1-2+3-(4-5)-6
      mov 20-8/4-5, 3+4*5-6
      end
    PRG
    program = parser.preprocess_and_parse(prog)
    expect(program.instructions.size).to eql(4)
    expect(program.instructions[0].a_operand.number).to eql(10)
    expect(program.instructions[0].b_operand.number).to eql(CORESIZE - 2)
    expect(program.instructions[1].a_operand.number).to eql(76)
    expect(program.instructions[1].b_operand.number).to eql(CORESIZE - 62)
    expect(program.instructions[2].a_operand.number).to eql(CORESIZE - 3)
    expect(program.instructions[2].b_operand.number).to eql(CORESIZE - 3)
    expect(program.instructions[3].a_operand.number).to eql(13)
    expect(program.instructions[3].b_operand.number).to eql(17)
  end

  it 'should parse a program with expressions' do
    parser = RuMARS::Parser.new(@settings)
    prog = <<~PRG
      ;redcode-94
             org start
      one    equ #1
      two    equ one + 1
             mov 1+2+3+4, two + 4
             add 1+3*4, 1+(3*4)
      start  sub 1*3-4, (1-3)*4
             sub 5-4-3-2-1, 5/4/3/2/1
             add 1+2*3+4, 4-3/2-1
             sub 10-9-8+7*6*5-4-3*2*1,10-(9-8)+7*6-(5-4)+3*2-1
             add 5||0, 2 + 3 && 1
             end
    PRG
    program = parser.preprocess_and_parse(prog)
    expect(program.instructions.size).to eql(7)
    expect(program.start_address).to eql(2)
    expect(program.instructions[0].a_operand.number).to eql(10)
    expect(program.instructions[0].b_operand.number).to eql(6)
    expect(program.instructions[1].a_operand.number).to eql(13)
    expect(program.instructions[1].b_operand.number).to eql(13)
    expect(program.instructions[2].a_operand.number).to eql(CORESIZE - 1)
    expect(program.instructions[2].b_operand.number).to eql(CORESIZE - 8)
    expect(program.instructions[3].a_operand.number).to eql(CORESIZE - 5)
    expect(program.instructions[3].b_operand.number).to eql(0)
    expect(program.instructions[4].a_operand.number).to eql(11)
    expect(program.instructions[4].b_operand.number).to eql(2)
    expect(program.instructions[5].a_operand.number).to eql(193)
    expect(program.instructions[5].b_operand.number).to eql(55)
    expect(program.instructions[6].a_operand.number).to eql(1)
    expect(program.instructions[6].b_operand.number).to eql(1)
  end

  it 'should expand a simple for loop' do
    parser = RuMARS::Parser.new(@settings)
    prog = <<~PRG
      ;redcode-94
             org start
      var    dat.f #0, #0
      start  nop.f #0
             for 3
             add #1, var
             rof
             end
    PRG
    program = parser.preprocess_and_parse(prog)
    expect(program.instructions.size).to eql(5)
    expect(program.start_address).to eql(1)
  end

  it 'should ignore the body of a 0 repeats for loop' do
    parser = RuMARS::Parser.new(@settings)
    prog = <<~PRG
      ;redcode-94
             org start
      var    dat.f #0, #0
      start  nop.f #0
             for 0
      This is not a valid instruction and should be ignored.
      This line as well!
             rof
             end
    PRG
    program = parser.preprocess_and_parse(prog)
    expect(program.instructions.size).to eql(2)
    expect(program.start_address).to eql(1)
  end

  it 'should expand a for loop with runtime variable' do
    parser = RuMARS::Parser.new(@settings)
    prog = <<~PRG
      ;redcode-94
             org start
      var    dat.f #0, #0
      start  nop.f #0
      i      for 3
      loop&i add #1+&i, var
             rof
             end
    PRG
    program = parser.preprocess_and_parse(prog)
    expect(program.instructions.size).to eql(5)
    expect(program.start_address).to eql(1)
  end

  it 'should expand nested for loops with runtime variable' do
    parser = RuMARS::Parser.new(@settings)
    prog = <<~PRG
      ;redcode-94
             org start
      var    dat.f #0, #0
      start  nop.f #0
      i      for 3
      loop&i add #1+&i, var
      j      for 2
      l&i&j  sub #1+&i+&j, var
             add #2+&i&j, var
             rof
             mul #1+&i, var
             rof
             end
    PRG
    program = parser.preprocess_and_parse(prog)
    expect(program.instructions.size).to eql(20)
    expect(program.start_address).to eql(1)
  end
end
