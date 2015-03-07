require 'rzubr'
require 'strscan'
require 'set'

# Deterministic Finite Automaton (DFA) table compiler from regular expressions.
# see Aho, et. al. ``COMPILERS PRINCIPLES TECHNIQUES, AND TOOLS'', 2007,
# Section 3.9 Algorithm  3.36

module RegularExpression
  class Grammar
    def initialize() @grammar_table = grammar_table end

    def grammar_table
      rule = Rzubr::Rule

      exp = rule.name(:exp) \
        > rule[:exp, '|', :cat]     & :parse_or \
        | rule[:cat]

      cat = rule.name(:cat) \
        > rule[:cat, :piece]        & :parse_cat \
        |

      piece = rule.name(:piece) \
        > rule[:atom, '?']          & :parse_ques \
        | rule[:atom, '*']          & :parse_star \
        | rule[:atom, '+']          & :parse_plus \
        | rule[:atom]

      atom = rule.name(:atom) \
        > rule[:char]               & :parse_char \
        | rule['(', :exp, ')']      & :parse_group

      g = (exp + cat + piece + atom).start(:exp)
      Rzubr::LALR1.new.rule(g)
    end

    def parse_or(v)    @builder.ornode(v[1], v[3]) end
    def parse_cat(v)   @builder.catnode(v[1], v[2]) end
    def parse_ques(v)  @builder.quesnode(v[1]) end
    def parse_star(v)  @builder.starnode(v[1]) end
    def parse_plus(v)  @builder.plusnode(v[1]) end
    def parse_char(v)  @builder.charnode(v[1]) end
    def parse_group(v) v[2] end

    def next_token(parser, scanner)
      if scanner.eos?
        parser.next_token(nil, nil)
        return
      end
      if scanner.scan(/\\(.)/)
        parser.next_token(:char, scanner[1])
      elsif scanner.scan(/([?*+|()])/)
        parser.next_token(scanner[1], scanner[1])
      elsif scanner.scan(/(.)/)
        parser.next_token(:char, scanner[1])
      else
        raise 'unexpected character'
      end
    end

    def parse(string, builder)
      @builder = builder
      scanner = StringScanner.new(string)
      driver = Rzubr::Parser.new(@grammar_table)
      driver.parse(self) {|parser| next_token(parser, scanner) }
      @builder.rootnode(driver.output)
      @builder = nil
      true
    end
  end# class Parser

  class DFACompiler
    attr_accessor :followpos, :leaves, :root, :dfa

    def initialize()
      @followpos, @leaves, @root, @dfa = {}, [], nil, []
      @parser = Grammar.new
    end

    def compile(string)
      @followpos.clear
      @leaves.clear
      @root = nil
      @parser.parse(string, self) and self.compose
    end

    State = Struct.new(:mark, :set)

    def compose
      @dfa.clear
      states = [State[false, @root.firstpos]]
      while state_from = states.index {|x| not x.mark }
        states[state_from].mark = true
        states[state_from].set.each do |i|
          ch = @leaves[i].ch
          if ch == :finish
            state_to = 0
          else
            u = states[state_from].set.select {|j| @leaves[j].ch == ch } \
                .inject(Set[]) {|r, j| r + @followpos[j] }
            state_to = states.index {|x| x.set == u }
            if state_to.nil?
              states.push State[false, u]
              state_to = states.size - 1
            end
          end
          @dfa[state_from] ||= {}
          @dfa[state_from][ch] = state_to
        end
      end
      compact
    end

    def compact
      group = [
        @dfa.each_index.select{|i| ! @dfa[i].key?(:finish) },
        @dfa.each_index.select{|i|   @dfa[i].key?(:finish) },
      ]
      while true
        compact_dfa = []
        next_group = []
        next_group_id = {}
        group.each_index do |gid|
          group[gid].each do |state|
            compact_state = {}
            @dfa[state].keys.each do |a|
              t = @dfa[state][a]
              compact_state[a] = group.find_index {|g| g.include?(t) }
            end
            if not next_group_id.key?(compact_state)
              compact_dfa.push compact_state
              next_group.push []
              next_group_id[compact_state] = next_group.size - 1
            end
            next_group[next_group_id[compact_state]].push state
          end
        end
        if group == next_group
          @dfa = compact_dfa
          break
        end
        group = next_group
      end
      self
    end

    def ornode(c1, c2) Ornode.new(c1, c2, self) end
    def catnode(c1, c2) Catnode.new(c1, c2, self) end
    def quesnode(c1) catnode(c1, Epsnode.new(self)) end
    def starnode(c1) Starnode.new(c1, self) end
    def plusnode(c1) catnode(c1, starnode(c1.copy)) end
    def charnode(ch) Charnode.new(ch, self) end
    def rootnode(c1) @root = catnode(c1, charnode(:finish)) end

    def add_leaf(node)
      i = @leaves.size
      @leaves.push node
      @followpos[i] = Set[]
      i
    end

    def update_followpos(to, from)
      to.each {|i| from.each {|j| @followpos[i] << j } }
    end

    class Ornode
      attr_accessor :c1, :c2, :nullable, :firstpos, :lastpos
      def initialize(c1, c2, ctx)
        @c1, @c2 = c1, c2
        @nullable = c1.nullable | c2.nullable
        @firstpos = c1.firstpos + c2.firstpos
        @lastpos = c1.lastpos + c2.lastpos
      end
      def copy(ctx) self.class.new(c1.copy(ctx), c2.copy(ctx), ctx) end
    end

    class Catnode
      attr_accessor :c1, :c2, :nullable, :firstpos, :lastpos
      def initialize(c1, c2, ctx)
        @c1, @c2 = c1, c2
        @nullable = c1.nullable & c2.nullable
        @firstpos = c1.nullable ? c1.firstpos + c2.firstpos : c1.firstpos
        @lastpos  = c2.nullable ? c1.firstpos + c2.firstpos : c2.firstpos
        ctx.update_followpos(c1.lastpos, c2.firstpos)
      end
      def copy(ctx) self.class.new(c1.copy(ctx), c2.copy(ctx), ctx) end
    end

    class Starnode
      attr_accessor :c1, :nullable, :firstpos, :lastpos
      def initialize(c1, ctx)
        @c1 = c1
        @nullable = true
        @firstpos = c1.firstpos
        @lastpos = c1.lastpos
        ctx.update_followpos(c1.lastpos, c1.firstpos)
      end
      def copy(ctx) self.class.new(c1.copy(ctx), ctx) end
    end

    class Charnode
      attr_accessor :ch, :nullable, :firstpos, :lastpos
      def initialize(ch, ctx)
        @ch = ch
        @nullable = false
        pos = ctx.add_leaf(self)
        @firstpos = Set[pos]
        @lastpos = Set[pos]
      end
      def copy(ctx) self.class.new(@ch, ctx) end
    end

    class Epsnode
      attr_accessor :nullable, :firstpos, :lastpos
      def initialize(ctx)
        @nullable = true
        @firstpos = Set[]
        @lastpos = Set[]
      end
      def copy(ctx) self.class.new(ctx) end
    end
  end #class DFACompiler
end #module RegularExpression

if __FILE__ == $0
  dfac = RegularExpression::DFACompiler.new
  # '(a|b)*abb'
  octet = '(' + (0..255).collect{|i| i.to_s }.join('|') + ')'
  dfac.compile(octet).dfa.each_with_index {|x, i|
    puts '%d %s' % [i, x.inspect]
  }
end

=begin
0 {"0"=>1, "1"=>2, "2"=>3, "3"=>4, "4"=>4, "5"=>4, "6"=>4, "7"=>4, "8"=>4, "9"=>4}
1 {:finish=>0}
2 {:finish=>0, "0"=>4, "1"=>4, "2"=>4, "3"=>4, "4"=>4, "5"=>4, "6"=>4, "7"=>4, "8"=>4, "9"=>4}
3 {:finish=>0, "0"=>4, "1"=>4, "2"=>4, "3"=>4, "4"=>4, "5"=>5, "6"=>1, "7"=>1, "8"=>1, "9"=>1}
4 {:finish=>0, "0"=>1, "1"=>1, "2"=>1, "3"=>1, "4"=>1, "5"=>1, "6"=>1, "7"=>1, "8"=>1, "9"=>1}
5 {:finish=>0, "0"=>1, "1"=>1, "2"=>1, "3"=>1, "4"=>1, "5"=>1}

(0|1([0-9][0-9]?)?|2([0-4][0-9]?|5[0-5]?|[6-9])?|[3-9][0-9]?)

=end

