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

    def rule(form, out = $stdout)
      @state.rule(form)
      err = fill_table(out)
      err += check_table(out)
      if err > 0
        list(out)
        raise "Grammar Critical Error"
      end
      self
    end

    def nonterminal() @state.grammar.nonterminal end
    def start_symbol() @state.grammar.start end
    def production() @state.grammar.production end
    def conflict_resolver() @state.grammar end

    def fill_table(out = $stdout)
      @action.clear
      @goto.clear
      reduce = []
      @state.transition.each_index do |state_p|
        @action[state_p] = {}
        @goto[state_p] = {}
        reduce[state_p] = {}
      end
      @state.accept.each {|state_p| @action[state_p][ENDMARK] = :accept }
      @lookahead = compute_lookahead
      @lookahead.each_pair do |(state_p, i), symbol_set|
        symbol_set.each do |symbol_a|
          if symbol_a != ENDMARK or @action[state_p][ENDMARK] != :accept
            reduce[state_p][symbol_a] ||= Set.new
            reduce[state_p][symbol_a] << i
          end
        end
      end
      rr_conflict = 0
      @action.each_index do |state_p|
        reduce[state_p].each_pair do |symbol_a, u|
          if u.size > 1
            out << "state #{state_p} reduce/reduce conflict #{symbol_a.inspect}.\n"
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
            when :nonassoc
              @action[state_p].delete symbol_a
            when :default
              @action[state_p][symbol_a] = state_r
              out << "state #{state_p} shift/reduce conflict #{symbol_a.inspect}.\n"
            when :error
              @action[state_p].delete symbol_a
              out << "state #{state_p} shift/reduce conflict #{symbol_a.inspect}.\n"
            end
          end
        end
      end
      rr_conflict
    end

    def check_table(out = $stdout)
      errs = 0
      nonterminal_shifts = Set.new
      nonterminal_reduces = Set.new
      @action.each_index do |state_p|
        if @action[state_p].empty?
          #  s  = r.name(:list) > r[:list, "X"]
          # or
          #  s  = r.name(:list) > r[:list1, "X"]
          #  s += r.name(:list1) > r[:list]
          errs += 1
          out << "state #{state_p} empty actions table entry. infinite loop in grammar?\n"
        else
          @action[state_p].each_pair do |symbol_a, x|
            next if symbol_a == ENDMARK
            case x
            when Integer
              nonterminal_shifts << symbol_a
            when Production
              nonterminal_reduces << symbol_a
            end
          end
        end
      end
      if not nonterminal_reduces.empty? and not nonterminal_reduces.subset?(nonterminal_shifts)
        # see http://lists.gnu.org/archive/html/help-bison/2006-06/msg00011.html
        #   s  = r.left('b').left('a')
        #   s += r.name(:s) > r[:a, 'b']
        #   s += r.name(:a) > r[:b]
        #   s += r.name(:b) > r['a'] | r[:a] % 'a'
        #
        #  stack                        input
        #  [0]   ["a", "b", "b", "b", "b", $]  shift "a" => state 4
        #  [0, 4]     ["b", "b", "b", "b", $]  reduce :b -> "a" / goto [0, :b] => state 3
        #  [0, 3]     ["b", "b", "b", "b", $]  reduce :a -> :b  / goto [0, :a] => state 2
        #  [0, 2]     ["b", "b", "b", "b", $]  reduce :b -> :a  / goto [0, :b] => state 3
        #  [0, 3]     ["b", "b", "b", "b", $]  reduce :a -> :b  / goto [0, :a] => state 2
        #  [0, 2]     ["b", "b", "b", "b", $]  reduce :b -> :a  / goto [0, :b] => state 3
        #  ... infinite
        errs += 1
        u = nonterminal_reduces - nonterminal_shifts
        u.each do |symbol_a|
          out << "reduce by #{symbol_a.inspect} but never shift by it. infinite loop in grammar?\n"
        end
      end
      errs
    end

    def list(out = '')
      @state.term.each_with_index do |s, state_p|
        out << 'state %d' % [state_p] << "\n"
        s.each do |i, pos|
          prod = @state.grammar.production[i]
          r = prod.rhs.map {|x| x.inspect }
          a = r[0 ... pos]
          b = r[pos .. -1]
          out << '      %s -> %s' % [prod.lhs.inspect, (a + ['_'] + b).join(' ')] << "\n"
        end
        out << "\n"
        @action[state_p].each_pair do |s, x|
          case x
          when Integer
            out << '  %-6s shift => state %d' % [s.inspect, x] << "\n"
          end
        end
        @goto[state_p].each_pair do |s, x|
          out << '  %-6s goto => state %d' % [s.inspect, x] << "\n"
        end
        @action[state_p].each_pair do |s, x|
          case x
          when :accept
            out << '  %-6s accept' % [s.inspect] << "\n"
          when Production
            out << '  %-6s reduce %s' % [s.inspect, x.inspect] << "\n"
          end
        end
        out << "\n"
      end
      out
    end

  private

    # F. L. DeRemer, T. J. Pennelo "Efficient Computation of LALR(1) Lookahead Sets",
    #   ACM Transactions on Programming Languages and Systems, Vol. 4, No. 4, 1982
    def compute_lookahead
      includes_relation = {}
      dr_set = {}
      nullable = select_nullable
      reads_relation = compute_reads_relation(includes_relation, dr_set, nullable)
      lookback_relation = compute_lookback_relation(includes_relation, nullable)
      read_set = union_find(dr_set, reads_relation)
      follow_set = union_find(read_set, includes_relation)
      lookahead_set = {}
      lookback_relation.each_pair do |x, rel|
        lookahead_set[x] = rel.inject(Set.new) {|r, y| r.merge follow_set[y] }
      end
      lookahead_set
    end

    def select_nullable
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

    def compute_reads_relation(includes_relation, dr_set, nullable)
      reads_relation = {}
      @state.transition.each_index do |state_p|
        @state.transition[state_p].each_pair do |symbol_a, state_r|
          nonterminal.key?(symbol_a) or next
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
      reads_relation
    end

    def compute_lookback_relation(includes_relation, nullable)
      lookback_relation = {}
      production.each_with_index do |prod, prod_rowid|
        if prod_rowid != 0
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
      end
      lookback_relation
    end

    def union_find(disjointset, relation)
      rank = []
      mark = {}
      disjointset.each_key {|x| mark[x] = 0 }
      disjointset.each_key do |x|
        mark[x] != 0 or union_find_loop(disjointset, relation, x, rank, mark)
      end
      disjointset
    end

    def union_find_loop(disjointset, relation, x, rank, mark)
      rank.push x
      mark[x] = d = rank.size
      relation[x].each do |y|
        mark[y] != 0 or union_find_loop(disjointset, relation, y, rank, mark)
        mark[x] = mark[x] < mark[y] ? mark[x] : mark[y]
        disjointset[x].merge disjointset[y]
      end
      if mark[x] == d
        begin
          mark[rank.last] = relation.size + 2
          disjointset[rank.last] = disjointset[x]
        end until rank.pop == x
      end
    end
  end
end

