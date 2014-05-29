require "rzubr/grammar"
require "rzubr/lr0"
require "set"

module Rzubr
  class LALR1
    attr_reader :state, :lookahead, :action, :goto

    def initialize
      @state = LR0.new
      @lookahead = {}
      @action = []
      @goto = []
    end

    def rule(form)
      @state.rule(form)
      fill_table
      self
    end

    def nonterminal() @state.grammar.nonterminal end
    def start_symbol() @state.grammar.start end
    def production() @state.grammar.production end
    def conflict_resolver() @state.grammar end

    def fill_table
      @action.clear
      @goto.clear
      reduce = []
      @state.transition.each_index do |state_p|
        @action[state_p] = {}
        @goto[state_p] = {}
        reduce[state_p] = {}
      end
      @state.accept.each do |state_p|
        @action[state_p][ENDMARK] = :accept
      end
      @lookahead = compute_lookahead
      @lookahead.each_pair do |(state_p, i), symbol_set|
        symbol_set.each do |symbol_a|
          next if symbol_a == ENDMARK and @action[state_p][ENDMARK] == :accept
          reduce[state_p][symbol_a] ||= Set.new
          reduce[state_p][symbol_a] << i
        end
      end
      rr_conflict = 0
      @action.each_index do |state_p|
        reduce[state_p].each_pair do |symbol_a, u|
          if u.size > 1
            puts "state #{state_p} reduce/reduce conflict #{symbol_a.inspect}."
            rr_conflict += 1
          end
          @action[state_p][symbol_a] = production[u.sort.first]
        end
        @state.transition[state_p].each_pair do |symbol_a, state_r|
          if nonterminal.key?(symbol_a)
            @goto[state_p][symbol_a] = state_r
          elsif not @action[state_p].key?(symbol_a)
            @action[state_p][symbol_a] = state_r
          else
            case conflict_resolver.resolve(symbol_a, @action[state_p][symbol_a])
            when :shift
              @action[state_p][symbol_a] = state_r
            when :reduce
              # action already has it.
            when :default
              @action[state_p][symbol_a] = state_r
              puts "state #{state_p} shift/reduce conflict #{symbol_a.inspect}."
            when :error
              @action[state_p].delete symbol_a
              puts "state #{state_p} shift/reduce conflict #{symbol_a.inspect}."
            end
          end
        end
      end
      if rr_conflict > 0
        raise "Grammar Critical Error"
      end
    end

  private

    # F. L. DeRemer, T. J. Pennelo "Efficient Computation of LALR(1) Lookahead Sets",
    #   ACM Transactions on Programming Languages and Systems, Vol. 4, No. 4, 1982
    def compute_lookahead
      nullable = select_nullable(production)
      dr_set = {}
      reads_relation = {}
      includes_relation = {}
      lookback_relation = {}
      @state.transition.each_index do |state_p|
        @state.transition[state_p].each_pair do |symbol_a, state_r|
          next unless nonterminal.key?(symbol_a)
          dr_set[[state_p, symbol_a]] = Set[]
          reads_relation[[state_p, symbol_a]] = Set[]
          includes_relation[[state_p, symbol_a]] = Set[]
          @state.transition[state_r].each_key do |symbol_x|
            if not nonterminal.key?(symbol_x)
              dr_set[[state_p, symbol_a]] << symbol_x
            elsif nullable.include?(symbol_x)
              reads_relation[[state_p, symbol_a]] << [state_r, symbol_x]
            end
          end
          if @state.accept.include?(state_r)
            dr_set[[state_p, symbol_a]] << ENDMARK
          end
        end
      end
      read_set = union_relation(dr_set, reads_relation)
      production.each_with_index do |prod, prod_rowid|
        next if prod_rowid == 0
        @state.start[prod_rowid].each do |state_p|
          state_q = state_p
          (0 ... prod.rhs.size).each do |pos|
            symbol_b = prod.rhs[pos]
            if nonterminal.key?(symbol_b) 
              if pos + 1 >= prod.rhs.size
                includes_relation[[state_q, symbol_b]] << [state_p, prod.lhs]
              elsif prod.rhs[pos + 1 .. -1].all? {|c| nullable.include?(c) }
                includes_relation[[state_q, symbol_b]] << [state_p, prod.lhs]
              end
            end
            state_q = @state.transition[state_q][symbol_b]
          end
          lookback_relation[[state_q, prod_rowid]] ||= Set.new
          lookback_relation[[state_q, prod_rowid]] << [state_p, prod.lhs]
        end
      end
      follow_set = union_relation(read_set, includes_relation)
      la_set = {}
      lookback_relation.each_pair do |x, rel|
        la_set[x] = rel.inject(Set.new){|r, y| r.merge follow_set[y] }
      end
      la_set
    end

    def select_nullable(production)
      nullable = Set.new
      changed = true
      while changed
        changed = false
        production.each do |e|
          if e.rhs.size == 0 or e.rhs.all? {|a| nullable.include?(a) }
            changed |= ! nullable.add?(e.lhs).nil?
          end
        end
      end
      nullable
    end

    def union_relation(f, relation)
      stack = []
      mark= {}
      f.each_key{|x| mark[x] = 0 }
      f.each_key do |x|
        next unless mark[x] == 0
        union_relation_traverse(x, relation, f, stack, mark)
      end
      f
    end

    def union_relation_traverse(x, relation, f, stack, mark)
      stack.push x
      mark[x] = d = stack.size
      relation[x].each do |y|
        if mark[y] == 0
          union_relation_traverse(y, relation, f, stack, mark)
        end
        mark[x] = mark[x] < mark[y] ? mark[x] : mark[y]
        f[x].merge f[y]
      end
      if mark[x] == d
        while true
          mark[stack.last] = relation.size + 2
          f[stack.last] = f[x]
          break if stack.pop == x
        end
      end
    end
  end
end

