# frozen_string_literal: true

require_relative '../lib/rumars/mars'

RSpec.describe RuMARS::MARS do
  it 'should execute the Imp program' do
    mars = RuMARS::MARS.new
    warrior = RuMARS::Warrior.new('Imp')
    prg = <<~"PRG"
      ;redcode-94
            mov +0, +1
            end
    PRG
    warrior.parse(prg)
    mars.add_warrior(warrior)
    mars.run(80)
    expect(mars.cycles).to eql(80)
  end

  it 'should execute the Dwarf program' do
    prg = <<~"PRG"
      ;redcode-94
            org start
            DAT.F   #0,   #0
      start ADD.AB  #4,   $-1
            MOV.AB  #0,   @-2
            JMP.A   $-2,  #0
            end
    PRG

    mars = RuMARS::MARS.new
    warrior = RuMARS::Warrior.new('Imp')
    warrior.parse(prg)
    mars.add_warrior(warrior)
    mars.run(4)
    expect(mars.cycles).to eql(4)
  end

  it 'should use the addressing modes correctly' do
    prg = <<~"PRG"
      ;redcode-94
            org start
            DAT.F   #0,   #0
      start ADD.AB  #4,   $-1
            MOV.AB  #0,   @-2
            JMP.A   $-2,  #0
            end
    PRG

    mars = RuMARS::MARS.new
    warrior = RuMARS::Warrior.new('Imp')
    warrior.parse(prg)
    mars.add_warrior(warrior)
    mars.run(4)
    expect(mars.cycles).to eql(4)
  end
end
