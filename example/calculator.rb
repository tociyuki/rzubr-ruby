require 'rzubr'
require 'strscan'

class Calculator
  def initialize() @grammar_table = grammar_table end

  def grammar_table
    rule = Rzubr::Rule
    prec = rule.
      left('+', '-').
      left('*', '/').
      right(:UPLUS, :UMINUS)

    lines = rule.name(:lines) \
      > rule[:lines, :expr, "\n"]  & :parse_lines_expr \
      | rule[:lines, "\n"] \
      | rule[] \
      | rule[:error, "\n"]         & :parse_lines_error

    expr = rule.name(:expr) \
      > rule[:expr, '+', :expr]    & :parse_expr_plus \
      | rule[:expr, '-', :expr]    & :parse_expr_minus \
      | rule[:expr, '*', :expr]    & :parse_expr_times \
      | rule[:expr, '/', :expr]    & :parse_expr_divide \
      | rule['(', :expr, ')']      & :parse_expr_subexpr \
      | rule['+', :expr] % :UPLUS  & :parse_expr_positive \
      | rule['-', :expr] % :UMINUS & :parse_expr_negative \
      | rule[:NUMBER] & :parse_expr_number

    g = (prec + lines + expr).start(:lines)
    Rzubr::LALR1.new.rule(g)
  end

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

  def calc
    scanner = StringScanner.new("-9+(-2-1)\n" + "2+3)\n" + "2+3\n")
    Rzubr::Parser.new(@grammar_table).parse(self) do |parser|
      next_token(parser, scanner)
    end
  end
end

if __FILE__ == $0
  Calculator.new.calc
end

