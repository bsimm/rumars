# frozen_string_literal: true

require_relative '../lib/rumars/mars'

RSpec.describe RuMARS::MARS do
  it 'should execute the Imp program' do
    mars = RuMARS::MARS.new
    warrior = RuMARS::Warrior.new('Imp')
    warrior.parse('MOV +0, +1')
    mars.add_warrior(warrior)
    mars.run(80)
    expect(mars.cycles).to eql(80)
  end

  it 'should execute the Dwarf program' do
    prg = <<~"PRG"
      DAT.F   #0,   #0
      ADD.AB  #4,   $-1
      MOV.AB  #0,   @-2
      JMP.A   $-2,  #0
    PRG

    mars = RuMARS::MARS.new
    warrior = RuMARS::Warrior.new('Imp')
    warrior.parse(prg)
    mars.add_warrior(warrior, 1)
    mars.run(4)
    expect(mars.cycles).to eql(4)
  end
end
