module Rzubr
  class Grammar
    attr_reader :precedence, :nonterminal, :start, :production

    def initialize
      @precedence = {}
      @nonterminal = {}
      @start = :start # fix
      @production = []
    end

    # set grammar rule [{terminal => precedences}, [productions]]
    def rule(form)
      (precdict, prodlist) = form
      @precedence.replace precdict
      @nonterminal.clear
      @production.clear
      prodlist.each do |prod|
        i = @production.size
        @production[i] = prod
        @nonterminal[prod.lhs] ||= []
        @nonterminal[prod.lhs] << i
      end
      self
    end

    # resolve shift/reduce conflict on terminal a and production prod
    def resolve(a, prod)
      r = prod.precedence
      return :default if not @precedence.key?(a) or not r or not @precedence.key?(r)
      if @precedence[a].score < @precedence[r].score
        :reduce
      elsif @precedence[a].score > @precedence[r].score
        :shift
      elsif @precedence[r].assoc == :left
        :reduce
      elsif @precedence[r].assoc == :right
        :shift
      elsif @precedence[r].assoc == :nonassoc
        :nonassoc
      else
        :error
      end
    end
  end

  class << (ENDMARK = Object.new)
    def to_s() '$' end
    def inspect() '$' end
  end

  class Precedence
    attr_reader :assoc, :score
    def self.[](*a) new(*a) end

    def initialize(assoc, score)
      @assoc, @score = assoc, score
    end

    def inspect() '%%%s(%d)' % [@assoc.to_s, @score] end
  end

  class Production
    attr_reader :lhs, :rhs, :precedence, :action
    def self.[](*a) new(*a) end

    def initialize(lhs, rhs, prec, action)
      raise ArgumentError, "lhs must not be nil!" if lhs.nil?
      @lhs, @rhs, @precedence, @action = lhs, rhs, prec, action
    end

    def inspect() '%s -> %s' % [@lhs.inspect, @rhs.map{|x| x.inspect }.join(' ')] end
  end
end

