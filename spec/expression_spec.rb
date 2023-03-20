# frozen_string_literal: true

require_relative '../lib/rumars/expression'

RSpec.describe RuMARS::Expression do
  it 'should support add operation' do
    ex = RuMARS::Expression.new(1, '+', 1)
    expect(ex.eval({})).to eql(2)

    ex = RuMARS::Expression.new(2, '-', 1)
    expect(ex.eval({})).to eql(1)

    ex = RuMARS::Expression.new(2, '*', 3)
    expect(ex.eval({})).to eql(6)

    ex = RuMARS::Expression.new(8, '/', 2)
    expect(ex.eval({})).to eql(4)

    ex = RuMARS::Expression.new(8, '%', 3)
    expect(ex.eval({})).to eql(2)
  end

  it 'should support symbol table lookups' do
    table = { 'one' => 1, 'two' => 2, 'three' => 3, 'eight' => 8 }

    ex = RuMARS::Expression.new(1, '+', 'one')
    expect(ex.eval(table)).to eql(2)

    ex = RuMARS::Expression.new('two', '-', 1)
    expect(ex.eval(table)).to eql(1)

    ex = RuMARS::Expression.new(2, '*', 'three')
    expect(ex.eval(table)).to eql(6)

    ex = RuMARS::Expression.new('eight', '/', 2)
    expect(ex.eval(table)).to eql(4)

    ex = RuMARS::Expression.new(8, '%', 'three')
    expect(ex.eval(table)).to eql(2)
  end

  it 'should support nested expressions' do
    ex1 = RuMARS::Expression.new(1, '+', 1)
    ex2 = RuMARS::Expression.new(4, '-', 1)

    ex = RuMARS::Expression.new(ex1, '*', ex2)
    expect(ex.eval({})).to eql(6)
  end
end
