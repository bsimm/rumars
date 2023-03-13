# frozen_string_literal: true

require_relative '../lib/rumars/parser'

RSpec.describe RuMARS::Parser do
  it 'should parse a simple program' do
    parser = RuMARS::Parser.new
    program = parser.parse('MOV 0, 1')
    pp program
  end
end
