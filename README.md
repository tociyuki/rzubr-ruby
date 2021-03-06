# Rzubr

Rzubr is a toy LALR(1) parsing table generator and its driver.
It also resolves shift/reduce conflicts with precedences of terminals
as similar as Yacc/Bison way.
The driver is almost equivalent from yaccpar with error recovery.

## Installation

Add this line to your application's Gemfile:

    gem 'rzubr'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install rzubr

## Usage

Rzubr::Rule provides you to write grammars with Ruby's expression.

For example, we write the grammar of the simple calculator.

```ruby
require 'rzubr'

class Calculator
  def grammar_table
    rule = Rzubr::Rule

    # declaration precedences: left, right, and nonassoc
    prec = rule.
      left('+', '-').
      left('*', '/').
      right(:UPLUS, :UMINUS)

    # productions
    # from BNF: C -> A B | D E F | G
    # to rzubr: rule.name(:C) > rule[:A, :B] | rule[:D, :E, :F] | rule[:G]

    # production lines in BNF rule[rhs] & semantic_action method names
    # NOTES: semantic actions must be methods without Proc objects.
    lines = rule.name(:lines) \
      > rule[:lines, :expr, "\n"]  & :parse_lines_expr \
      | rule[:lines, "\n"] \
      | rule[] \
      | rule[:error, "\n"]         & :parse_lines_error

    # production expr in BNF rule[rhs] % precedence token & semantic action
    expr = rule.name(:expr) \
      > rule[:expr, '+', :expr]    & :parse_expr_plus \
      | rule[:expr, '-', :expr]    & :parse_expr_minus \
      | rule[:expr, '*', :expr]    & :parse_expr_times \
      | rule[:expr, '/', :expr]    & :parse_expr_divide \
      | rule['(', :expr, ')']      & :parse_expr_subexpr \
      | rule['+', :expr] % :UPLUS  & :parse_expr_positive \
      | rule['-', :expr] % :UMINUS & :parse_expr_negative \
      | rule[:NUMBER]              & :parse_expr_number

    # the calculator grammar from them
    g = (prec + lines + expr).start(:lines)
    # generate LALR(1) parsing table of it
    Rzubr::LALR1.new.rule(g)
  end

  # semantic action methods
  def parse_lines_expr(v)    puts v[2] end
  def parse_lines_error(yy)  puts 'Error'; yy.error_ok end
  def parse_expr_plus(v)     v[1] + v[3] end
  def parse_expr_minus(v)    v[1] - v[3] end
  def parse_expr_times(v)    v[1] * v[3] end
  def parse_expr_divide(v)   v[1] / v[3] end
  def parse_expr_subexpr(v)  v[2] end
  def parse_expr_positive(v) v[2] end
  def parse_expr_negative(v) -v[2] end
  def parse_expr_number(v)   v[1] end
end
```

Here is a lexical scanner with StringScanner.
On end of input, scanner passes nil into parser as the ENDMARK.

```ruby
require 'strscan'

class Calculator
  def next_token(parser, scanner)
    if scanner.eos?
      parser.next_token(nil, nil)
      return
    end
    scanner.scan(/[ \t]+/)
    if scanner.scan(/([-+*\/()])/)
      parser.next_token(scanner[1], scanner[1])
    elsif scanner.scan(/([0-9]+)/)
      parser.next_token(:NUMBER, scanner[1].to_f)
    elsif scanner.scan(/\n/)
      parser.next_token("\n", "\n")
    else
      raise 'unexpected character'
    end
  end
end
```

Let's run our calculator with parser.

```ruby
class Calculator
  def initialize() @grammar_table = grammar_table end

  def calc
    scanner = StringScanner.new("-9+(-2-1)\n" + "2+3)\n" + "2+3\n")
    Rzubr::Parser.new(@grammar_table).parse(self) do |parser|
      next_token(parser, scanner)
    end
  end
end

Calculator.new.calc()
```

## Contributing

1. Fork it ( https://github.com/tociyuki/rzubr-ruby/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
