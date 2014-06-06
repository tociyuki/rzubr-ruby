require 'rspec'
require 'rzubr'

def conflict_rr
  r = Rzubr::Rule
  s  = r.name(:S) > r['a', :A, 'd'] | r['b', :B, 'd'] | r['a', :B, 'e'] | r['b', :A, 'e']
  s += r.name(:A) > r['c']
  s += r.name(:B) > r['c']
  Rzubr::LALR1.new.rule(s.start(:S), '')
end

describe Rzubr do
  it 'should check infinite loop.' do
    expect { conflict_rr() }.to raise_error(RuntimeError, /Grammar/)
  end
end

