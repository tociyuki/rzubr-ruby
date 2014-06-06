require 'rspec'
require 'rzubr'

class Calc
  def grammar_table
    r = Rzubr::Rule
    s = r.left('+').left('*')
    s += r.name(:E) \
      > r[:E, '+', :E]  & :add \
      | r[:E, '*', :E]  & :mul \
      | r['(', :E, ')'] & :subexpr \
      | r[:x]
    Rzubr::LALR1.new.rule(s.start(:E))
  end
  def add(v) [v[1], '+', v[3]] end
  def mul(v) [v[1], '*', v[3]] end
  def subexpr(v) v[2] end

  def parse(tbl, src)
    scanner = src.to_enum
    Rzubr::Parser.new(tbl).parse(self) {|parser|
      t, v = scanner.next
      parser.next_token(t, v || t)
    }.output
  end
end

describe Rzubr do
  before(:all) { @gtbl = Calc.new.grammar_table }
  it 'should make a grammar table' do
    expect(@gtbl).to be_a(Rzubr::LALR1)
  end
  it 'should parse 1 + 2' do
    src = [[:x, 1], ['+'], [:x, 2], [false, '$']].to_enum
    expect(Calc.new.parse(@gtbl, src)).to eq([1, '+', 2])
  end
  it 'should parse 1 * 2' do
    src = [[:x, 1], ['*'], [:x, 2], [false, '$']].to_enum
    expect(Calc.new.parse(@gtbl, src)).to eq([1, '*', 2])
  end
  it 'should parse 1 + 2 + 3' do
    src = [[:x, 1], ['+'], [:x, 2], ['+'], [:x, 3], [false, '$']].to_enum
    expect(Calc.new.parse(@gtbl, src)).to eq([[1, '+', 2], '+', 3])
  end
  it 'should parse 1 * 2 * 3' do
    src = [[:x, 1], ['*'], [:x, 2], ['*'], [:x, 3], [false, '$']].to_enum
    expect(Calc.new.parse(@gtbl, src)).to eq([[1, '*', 2], '*', 3])
  end
  it 'should parse 1 * 2 + 3' do
    src = [[:x, 1], ['*'], [:x, 2], ['+'], [:x, 3], [false, '$']].to_enum
    expect(Calc.new.parse(@gtbl, src)).to eq([[1, '*', 2], '+', 3])
  end
  it 'should parse 1 + 2 * 3' do
    src = [[:x, 1], ['+'], [:x, 2], ['*'], [:x, 3], [false, '$']].to_enum
    expect(Calc.new.parse(@gtbl, src)).to eq([1, '+', [2, '*', 3]])
  end
  it 'should parse 1 * (2 + 3)' do
    src = [[:x, 1], ['*'], ['('], [:x, 2], ['+'], [:x, 3], [')'], [false, '$']].to_enum
    expect(Calc.new.parse(@gtbl, src)).to eq([1, '*', [2, '+', 3]])
  end
  it 'should parse (1 + 2) * 3' do
    src = [['('], [:x, 1], ['+'], [:x, 2], [')'], ['*'], [:x, 3], [false, '$']].to_enum
    expect(Calc.new.parse(@gtbl, src)).to eq([[1, '+', 2], '*', 3])
  end
end

