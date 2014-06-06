require 'rspec'
require 'rzubr'

def infinite
  r = Rzubr::Rule
  s  = r.name(:list) > r[:list, "X"]
  Rzubr::LALR1.new.rule(s.start(:list), '')
end

def infinite2
  r = Rzubr::Rule
  s  = r.name(:list) > r[:list1, "X"]
  s += r.name(:list1) > r[:list]
  Rzubr::LALR1.new.rule(s.start(:list), '')
end


def infinite_sylvain
# http://lists.gnu.org/archive/html/help-bison/2006-06/msg00011.html
# From: 	Sylvain Schmitz
# Subject: 	Re: avoiding infinite loops
# Date: 	Tue, 13 Jun 2006 23:51:39 +0200
  r = Rzubr::Rule
  s  = r.left('b').left('a')
  s += r.name(:s) > r[:a, 'b']
  s += r.name(:a) > r[:b]
  s += r.name(:b) > r['a'] | r[:a] % 'a'
  Rzubr::LALR1.new.rule(s.start(:s), '')
end

describe Rzubr do
  it 'should check infinite loop.' do
    expect { infinite() }.to raise_error(RuntimeError, /Grammar/)
  end
  it 'should check infinite loop 2.' do
    expect { infinite2() }.to raise_error(RuntimeError, /Grammar/)
  end
  it 'should check infinite loop by Sylvain Schmitz.' do
    expect { infinite_sylvain() }.to raise_error(RuntimeError, /Grammar/)
  end
end

