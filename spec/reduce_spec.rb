require 'rspec'
require 'rzubr'

class LogoFunc
  def initialize
    @parser = Rzubr::Parser.new(grammar_table)
  end

  def grammar_table
    r = Rzubr::Rule
    s  = r.name(:s) \
       > r[:s, :e]                   & :sequence \
       | r[:e]                       & :sequence1
    s += r.name(:e) \
       > r[:fn0]                     & :function0 \
       | r[:fn1, :e]                 & :function1 \
       | r[:fn2, :e, :e]             & :function2 \
       | r[:fn3, :e, :e, :e]         & :function3 \
       | r[:fn4, :e, :e, :e, :e]     & :function4 \
       | r[:fn5, :e, :e, :e, :e, :e] & :function5 \
       | r[:atom]                    & :primaryatom
    Rzubr::LALR1.new.rule(s.start(:s))
  end
  def sequence(v)  v[1] + [v[2]] end
  def sequence1(v) [v[1]] end
  def function0(v) [v[1]] end
  def function1(v) [v[1], v[2]] end
  def function2(v) [v[1], v[2], v[3]] end
  def function3(v) [v[1], v[2], v[3], v[4]] end
  def function4(v) [v[1], v[2], v[3], v[4], v[5]] end
  def function5(v) [v[1], v[2], v[3], v[4], v[5], v[6]] end
  def subexpr(v)     v[2] end
  def primaryatom(v) v[1] end

  def parse(a)
    scanner = a.to_enum
    @parser.parse(self) {|parser|
      t, v = scanner.next
      parser.next_token(t, v || t)
    }.output
  end
end

describe Rzubr do
  before(:all) { @logo = LogoFunc.new }
  it 'should parse 1' do
    src = [[:atom, 1], [false, '$']]
    expect(@logo.parse(src)).to eq([1])
  end
  it 'should parse f0 !' do
    src = [[:fn0, 'f'],
           [:atom, '!'], [false, '$']]
    expect(@logo.parse(src)).to eq([['f'], '!'])
  end
  it 'should parse f1 1 !' do
    src = [[:fn1, 'f'], [:atom, 1],
           [:atom, '!'], [false, '$']]
    expect(@logo.parse(src)).to eq([['f', 1], '!'])
  end
  it 'should parse f2 1 2 !' do
    src = [[:fn2, 'f'], [:atom, 1], [:atom, 2],
           [:atom, '!'], [false, '$']]
    expect(@logo.parse(src)).to eq([['f', 1, 2], '!'])
  end
  it 'should parse f3 1 2 3 !' do
    src = [[:fn3, 'f'], [:atom, 1], [:atom, 2], [:atom, 3],
           [:atom, '!'], [false, '$']]
    expect(@logo.parse(src)).to eq([['f', 1, 2, 3], '!'])
  end
  it 'should parse f4 1 2 3 4 !' do
    src = [[:fn4, 'f'], [:atom, 1], [:atom, 2], [:atom, 3], [:atom, 4],
           [:atom, '!'], [false, '$']]
    expect(@logo.parse(src)).to eq([['f', 1, 2, 3, 4], '!'])
  end
  it 'should parse f5 1 2 3 4 5 !' do
    src = [[:fn5, 'f'], [:atom, 1], [:atom, 2], [:atom, 3], [:atom, 4], [:atom, 5],
           [:atom, '!'], [false, '$']]
    expect(@logo.parse(src)).to eq([['f', 1, 2, 3, 4, 5], '!'])
  end

  it 'should parse f0 f1 1 f2 1 2 .. f5 1 2 3 4 5 !' do
    src = [[:fn0, 'f0'],
           [:fn1, 'f1'], [:atom, 1],
           [:fn2, 'f2'], [:atom, 1], [:atom, 2],
           [:fn3, 'f3'], [:atom, 1], [:atom, 2], [:atom, 3],
           [:fn4, 'f4'], [:atom, 1], [:atom, 2], [:atom, 3], [:atom, 4],
           [:fn5, 'f5'], [:atom, 1], [:atom, 2], [:atom, 3], [:atom, 4], [:atom, 5],
           [:atom, '!'], [false, '$']]
    parsed = [
           ['f0'],
           ['f1', 1],
           ['f2', 1, 2],
           ['f3', 1, 2, 3],
           ['f4', 1, 2, 3, 4],
           ['f5', 1, 2, 3, 4, 5],
           '!']
    expect(@logo.parse(src)).to eq(parsed)
  end

  it 'should parse f1 1 g1 2 !' do
    src = [[:fn1, 'f1'], [:atom, 1], [:fn1, 'g1'], [:atom, 2],
           [:atom, '!'], [false, '$']]
    expect(@logo.parse(src)).to eq([['f1', 1], ['g1', 2], '!'])
  end
  it 'should parse f1 g1 1 !' do
    src = [[:fn1, 'f1'], [:fn1, 'g1'], [:atom, 1],
           [:atom, '!'], [false, '$']]
    expect(@logo.parse(src)).to eq([['f1', ['g1', 1]], '!'])
  end
  it 'should parse f2 g1 1 2 !' do
    src = [[:fn2, 'f2'], [:fn1, 'g1'], [:atom, 1], [:atom, 2],
           [:atom, '!'], [false, '$']]
    expect(@logo.parse(src)).to eq([['f2', ['g1', 1], 2], '!'])
  end
  it 'should parse f2 1 g1 2 !' do
    src = [[:fn2, 'f2'], [:atom, 1], [:fn1, 'g1'], [:atom, 2],
           [:atom, '!'], [false, '$']]
    expect(@logo.parse(src)).to eq([['f2', 1, ['g1', 2]], '!'])
  end
  it 'should parse f2 g2 1 h1 2 3 !' do
    src = [[:fn2, 'f2'], [:fn2, 'g2'], [:atom, 1], [:fn1, 'h1'], [:atom, 2], [:atom, 3],
           [:atom, '!'], [false, '$']]
    expect(@logo.parse(src)).to eq([['f2', ['g2', 1, ['h1', 2]], 3], '!'])
  end
  it 'should parse f2 g2 h1 1 2 3 !' do
    src = [[:fn2, 'f2'], [:fn2, 'g2'], [:fn1, 'h1'], [:atom, 1], [:atom, 2], [:atom, 3],
           [:atom, '!'], [false, '$']]
    expect(@logo.parse(src)).to eq([['f2', ['g2', ['h1', 1], 2], 3], '!'])
  end
end

