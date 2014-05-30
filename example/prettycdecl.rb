require 'rzubr'
require 'strscan'
require 'readline'
require 'set'

=begin
pretty describe ANSI C limited declarations.

    $ ruby example/prettycdecl.rb
    input declaration of ANSI C. "quit" or "." for end.
    > int a;
    a: int.
    > int (*p[5])[3];
    p: array[5] of pointer to array[3] of int.
    > char (*(*fp)(void))(int);
    fp: pointer to function(void) returning pointer to function(int) returning char.
    > char *(*c[10])(int *p);
    c: array[10] of pointer to function(p: pointer to int) returning pointer to char.
    > int (*(*p)(int *a))[5]; 
    p: pointer to function(a: pointer to int) returning pointer to array[5] of int.
    > .
    $

=end

class PrettyANSICDeclaration
  KEYWORD = Set[
    'auto', 'char', 'const', 'double', 'extern', 'float', 'int', 'long',
    'register', 'short', 'signed', 'static', 'unsigned', 'void', 'volatile']

  def grammar_table
    rule = Rzubr::Rule

    s = rule.name(:program) \
      > rule[:declaration] \
      | rule[:program, :declaration]

    s += rule.name(:declaration) \
      > rule[:declaration_specifiers, ';'] & :puts_declaration \
      | rule[:declaration_specifiers,  :declarator_list, ';'] & :puts_declaration_list

    s += rule.name(:declaration_specifiers) \
      > rule[:storage_class_specifier] \
      | rule[:storage_class_specifier, :declaration_specifiers] & :concat_string \
      | rule[:type_qualifier] \
      | rule[:type_qualifier, :declaration_specifiers] & :concat_string \
      | rule[:type_specifier] \
      | rule[:type_specifier, :declaration_specifiers] & :concat_string

    s += rule.name(:declarator_list) \
      > rule[:declarator] & :declarator_list_first \
      | rule[:declarator_list, ',', :declarator] & :declarator_list

    s += rule.name(:declarator) \
      > rule[:pointer, :direct_declarator] & :reverse_concat_string \
      | rule[:direct_declarator]

    s += rule.name(:storage_class_specifier) \
      > rule['extern'] | rule['static'] | rule['auto'] | rule['register']

    s += rule.name(:type_qualifier) \
      > rule['const'] | rule['valatile']

    s += rule.name(:type_specifier) \
      > rule['void'] | rule['signed'] | rule['unsigned'] \
      | rule['char'] | rule['short'] | rule['int'] | rule['long'] \
      | rule['float'] | rule['double']

    s += rule.name(:type_qualifier_list) \
      > rule[:type_qualifier] \
      | rule[:type_qualifier_list, :type_qualifier] & :concat_string

    s += rule.name(:pointer) \
      > rule['*'] & :pointer_to \
      | rule['*', :type_qualifier_list] & :type_pointer_to \
      | rule['*', :pointer] & :type_pointer_to \
      | rule['*', :type_qualifier_list, :pointer] & :type_qualifier_pointer_to

    s += rule.name(:constant_expression) \
      > rule[:CONSTANT]

    s += rule.name(:direct_declarator) \
      > rule[:IDENTIFIER] & :direct_identifier \
      | rule['(', :declarator, ')'] & :direct_paren \
      | rule[:direct_declarator, '[', :constant_expression, ']'] & :direct_sized_array \
      | rule[:direct_declarator, '[', ']'] & :direct_array \
      | rule[:direct_declarator, '(', :parameter_type_list, ')'] & :direct_function_param \
      | rule[:direct_declarator, '(', ')'] & :direct_function

    s += rule.name(:abstract_declarator) \
      > rule[:pointer] \
      | rule[:direct_abstract_declarator] \
      | rule[:pointer, :direct_abstract_declarator] & :reverse_concat_string

    s += rule.name(:direct_abstract_declarator) \
      > rule['(', :abstract_declarator, ')'] \
      | rule['[', ']'] & :direct_abstract_array \
      | rule['[', :constant_expression, ']'] & :direct_abstract_sized_array \
      | rule[:direct_abstract_declarator, '[', ']'] & :direct_array \
      | rule[:direct_abstract_declarator, '[', :constant_expression, ']'] & :direct_sized_array \
      | rule['(', ')'] & :direct_abstract_function \
      | rule['(', :parameter_type_list, ')'] & :direct_abstract_function_param \
      | rule[:direct_abstract_declarator, '(', ')'] & :direct_function \
      | rule[:direct_abstract_declarator, '(', :parameter_type_list, ')'] & :direct_function_param

    s += rule.name(:parameter_type_list) \
      > rule[:parameter_list] \
      | rule[:parameter_list, ',', '...'] & :parameter_list

    s += rule.name(:parameter_list) \
      > rule[:parameter_declaration] \
      | rule[:parameter_list, ',', :parameter_declaration] & :parameter_list

    s += rule.name(:parameter_declaration) \
      > rule[:declaration_specifiers, :declarator] & :reverse_concat_string \
      | rule[:declaration_specifiers, :abstract_declarator] & :reverse_concat_string \
      | rule[:declaration_specifiers]

    Rzubr::LALR1.new.rule(s.start(:program))
  end

  def puts_declaration(v) puts v[1]; nil end
  def puts_declaration_list(v) print v[2].collect{|x| "#{x} #{v[1]}.\n" }.join; nil end

  def declarator_list_first(v) [v[1]] end
  def declarator_list(v) v[1] << v[3] end

  def type_pointer_to(v) "#{v[2]} pointer to" end
  def type_qualifier_pointer_to(v) "#{v[3]} #{v[2]} pointer to" end

  def direct_identifier(v) "#{v[1]}:" end
  def direct_paren(v) v[2] end
  def direct_sized_array(v) "#{v[1]} array[#{v[3]}] of" end
  def direct_array(v) "#{v[1]} array[] of" end
  def direct_function_param(v) "#{v[1]} function(#{v[3]}) returning" end
  def direct_function(v) "#{v[1]} function() returning" end

  def direct_abstract_array(v) "array[] of" end
  def direct_abstract_sized_array(v) "array[#{v[2]}] of" end
  def direct_abstract_function_param(v) "function(#{v[2]}) returning" end
  def direct_abstract_function(v) "function() returning" end

  def parameter_list(v) "#{v[1]}, #{v[3]}" end

  def concat_string(v) [v[1], v[2]].join(' ') end
  def reverse_concat_string(v) [v[2], v[1]].join(' ') end
  def pointer_to(v) 'pointer to' end

  def next_token(parser, scanner)
    while not scanner.eos?
      scanner.scan(/[ \t\f\v\n]+/)
      scanner.scan(/\/\*.*?\*\//m)
      if x = scanner.scan(/[a-zA-Z_][a-zA-Z0-9_]*/)
        return parser.next_token(KEYWORD.member?(x) ? x : :IDENTIFIER, x)
      elsif x = scanner.scan(/[0-9]+/)
        return parser.next_token(:CONSTANT, x)
      elsif x = scanner.scan(/(?:\.\.\.|[*;,\[\]\(\)])/)
        return parser.next_token(x, x)
      else
        scanner.get_byte
      end
    end
    parser.next_token(nil, '$')
  end

  def run
    puts 'input declaration of ANSI C. "quit" or "." for end.'
    parser = Rzubr::Parser.new(grammar_table)
    while buf = Readline.readline('> ', true)
      break if buf == 'quit' || buf == '.'
      next if /^\s*$/ =~ buf
      scanner = StringScanner.new(buf)
      begin
        parser.parse(self) { next_token(parser, scanner) }
      rescue
        put "syntax error on #{parser.token_value.inspect}."
      end
    end
  end
end

PrettyANSICDeclaration.new.run

