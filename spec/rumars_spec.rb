# frozen_string_literal: true

require_relative '../lib/rumars/mars'

RSpec.describe RuMARS::MARS do
  it 'should execute the Imp program' do
    mars = RuMARS::MARS.new
    warrior = RuMARS::Warrior.new('Imp')
    warrior.parse('MOV +0, +1')
    mars.add_warrior(warrior)
    mars.run
  end
end
