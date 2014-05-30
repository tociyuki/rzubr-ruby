require "rzubr/grammar"

module Rzubr
  class Rule
    attr_reader :prec, :prod
    def initialize(prec, prod) @prec, @prod = prec, prod end
    def +(x) Rule.new(@prec + x.prec, @prod + x.prod) end
    def self.left(*a)     Rule.new([[:left, *a]], []) end
    def self.right(*a)    Rule.new([[:right, *a]], []) end
    def self.nonassoc(*a) Rule.new([[:nonassoc, *a]], []) end
    def left(*a)     Rule.new(@prec + [[:left, *a]], @prod) end
    def right(*a)    Rule.new(@prec + [[:right, *a]], @prod) end
    def nonassoc(*a) Rule.new(@prec + [[:nonassoc, *a]], @prod) end
    def self.name(sym) Rule.new([], [[sym, [], nil, nil]]) end
    def self.[](*a)    Rule.new([], [[nil, a, nil, nil]]) end
    def %(x) Rule.new(@prec, [[@prod[0][0], @prod[0][1], x, @prod[0][3]]]) end
    def &(x) Rule.new(@prec, [[@prod[0][0], @prod[0][1], @prod[0][2], x]]) end
    def |(x) Rule.new(@prec, @prod + x.prod) end
    def >(a) Rule.new(@prec, a.prod.collect{|x| [@prod[0][0], x[1], x[2], x[3]] }) end

    def start(x)
      prectbl = {}
      prodlist = [Production.new(:start, [x], nil, nil)]
      score = 1
      @prec.each do |assoc, *a|
        a.each {|x| prectbl[x] = Precedence.new(assoc, score) }
        score += 1
      end
      @prod.each do |lhs, rhs, prec, action|
        if prec.nil?
          rhs.each {|x| if prectbl.key?(x) then prec = x end }
        end
        prodlist << Production.new(lhs, rhs, prec, action)
      end
      [prectbl, prodlist]
    end
  end
end

