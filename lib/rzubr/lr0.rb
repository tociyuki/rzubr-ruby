require "rzubr/grammar"
require "set"

module Rzubr
  class LR0
    attr_reader :grammar, :start, :transition, :accept, :term

    def initialize
      @grammar = Grammar.new
      @start = []
      @transition = []
      @accept = []
      @term = []
    end

    def rule(form)
      @grammar.rule(form)
      @start.replace(production.collect{ [] })
      @transition.clear
      @accept.clear
      @term.clear
      fill_transition
      select_start_accept
      self
    end

    def nonterminal() @grammar.nonterminal end
    def start_symbol() @grammar.start end
    def production() @grammar.production end

  private

    def fill_transition
      @term[0] = closure(Set.new(nonterminal[start_symbol].collect{|i| [i, 0] }))
      @transition[0] = {}
      kont = [0]
      while not kont.empty?
        state_p = kont.shift
        @term[state_p].each do |i, pos|
          next unless pos < production[i].rhs.size
          x = production[i].rhs[pos]
          termset_r = goto_closure(@term[state_p], x)
          state_r = @term.index(termset_r)
          if state_r.nil?
            state_r = @term.size
            @term[state_r] = termset_r
            @transition[state_r] = {}
            kont.push state_r
          end
          @transition[state_p][x] = state_r
        end
      end
      self
    end

    def select_start_accept
      @term.each_with_index do |termset_p, state_p|
        termset_p.each do |i, pos|
          if pos == 0
            @start[i] << state_p
          end
          if production[i].lhs == start_symbol and production[i].rhs.size <= pos
            @accept << state_p
          end
        end
      end
      self
    end

    def closure(termset)
      already = Set.new
      while true
        a = Set.new
        termset.each do |i, pos|
          next unless pos < production[i].rhs.size
          b = production[i].rhs[pos]
          next unless nonterminal.key?(b)
          next if already.include?(b)
          already << b
          nonterminal[b].each do |j|
            next if termset.include?([j, 0])
            a << [j, 0]
          end
        end
        break if a.empty?
        termset.merge a
      end
      termset
    end

    def goto_closure(termset_p, x)
      termset_r = Set.new
      termset_p.each do |i, pos|
        next unless pos < production[i].rhs.size
        next unless production[i].rhs[pos] == x
        termset_r << [i, pos + 1]
      end
      closure(termset_r)
    end
  end
end

