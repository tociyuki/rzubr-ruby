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
    s = rule_program \
      + rule_declaration \
      + rule_declaration_specifiers \
      + rule_declarator_list \
      + rule_storage_class_specifier \
      + rule_type_qualifier \
      + rule_type_specifier \
      + rule_type_qualifier_list \
      + rule_declarator \
      + rule_pointer \
      + rule_direct_declarator \
      + rule_abstract_declarator \
      + rule_direct_abstract_declarator \
      + rule_parameter_type_list \
      + rule_parameter_list \
      + rule_parameter_declaration \
      + rule_constant_expression

    Rzubr::LALR1.new.rule(s.start(:program))
  end

  def rule() Rzubr::Rule end
  alias :seq :rule

  def rule_program
    rule.name(:program) \
      > seq[:declaration] \
      | seq[:program, :declaration]
  end

  def rule_declaration
    rule.name(:declaration) \
      > seq[:declaration_specifiers, ';'] & :puts_declaration \
      | seq[:declaration_specifiers,  :declarator_list, ';'] & :puts_declaration_list
  end
  def puts_declaration(v) puts v[1]; nil end
  def puts_declaration_list(v) print v[2].collect{|x| "#{x} #{v[1]}.\n" }.join; nil end

  def rule_declaration_specifiers
    rule.name(:declaration_specifiers) \
      > seq[:storage_class_specifier] \
      | seq[:storage_class_specifier, :declaration_specifiers] & :concat_string \
      | seq[:type_qualifier] \
      | seq[:type_qualifier, :declaration_specifiers] & :concat_string \
      | seq[:type_specifier] \
      | seq[:type_specifier, :declaration_specifiers] & :concat_string
  end
  def concat_string(v) [v[1], v[2]].join(' ') end

  def rule_declarator_list
    rule.name(:declarator_list) \
      > seq[:declarator] & :declarator_list_first \
      | seq[:declarator_list, ',', :declarator] & :declarator_list
  end
  def declarator_list_first(v) [v[1]] end
  def declarator_list(v) v[1] << v[3] end

  def rule_storage_class_specifier
    rule.name(:storage_class_specifier) \
      > seq['extern'] | seq['static'] | seq['auto'] | seq['register']
  end

  def rule_type_qualifier
    rule.name(:type_qualifier) \
      > seq['const'] | seq['valatile']
  end

  def rule_type_specifier
    rule.name(:type_specifier) \
      > seq['void'] | seq['signed'] | seq['unsigned'] \
      | seq['char'] | seq['short'] | seq['int'] | seq['long'] \
      | seq['float'] | seq['double']
  end

  def rule_type_qualifier_list
    rule.name(:type_qualifier_list) \
      > seq[:type_qualifier] \
      | seq[:type_qualifier_list, :type_qualifier] & :concat_string
  end

  def rule_declarator
    rule.name(:declarator) \
      > seq[:pointer, :direct_declarator] & :reverse_concat_string \
      | seq[:direct_declarator]
  end
  def reverse_concat_string(v) [v[2], v[1]].join(' ') end

  def rule_pointer
    rule.name(:pointer) \
      > seq['*'] & :pointer_to \
      | seq['*', :type_qualifier_list] & :type_pointer_to \
      | seq['*', :pointer] & :type_pointer_to \
      | seq['*', :type_qualifier_list, :pointer] & :type_qualifier_pointer_to
  end
  def pointer_to(v) 'pointer to' end
  def type_pointer_to(v) "#{v[2]} pointer to" end
  def type_qualifier_pointer_to(v) "#{v[3]} #{v[2]} pointer to" end

  def rule_direct_declarator
    rule.name(:direct_declarator) \
      > seq[:IDENTIFIER] & :direct_identifier \
      | seq['(', :declarator, ')'] & :direct_paren \
      | seq[:direct_declarator, '[', :constant_expression, ']'] & :direct_sized_array \
      | seq[:direct_declarator, '[', ']'] & :direct_array \
      | seq[:direct_declarator, '(', :parameter_type_list, ')'] & :direct_function_param \
      | seq[:direct_declarator, '(', ')'] & :direct_function
  end
  def direct_identifier(v) "#{v[1]}:" end
  def direct_paren(v) v[2] end
  def direct_sized_array(v) "#{v[1]} array[#{v[3]}] of" end
  def direct_array(v) "#{v[1]} array[] of" end
  def direct_function_param(v) "#{v[1]} function(#{v[3]}) returning" end
  def direct_function(v) "#{v[1]} function() returning" end

  def rule_constant_expression
    rule.name(:constant_expression) \
      > seq[:CONSTANT]
  end

  def rule_parameter_type_list
    rule.name(:parameter_type_list) \
      > seq[:parameter_list] \
      | seq[:parameter_list, ',', '...'] & :parameter_list
  end
  def parameter_list(v) "#{v[1]}, #{v[3]}" end

  def rule_parameter_list
    rule.name(:parameter_list) \
      > seq[:parameter_declaration] \
      | seq[:parameter_list, ',', :parameter_declaration] & :parameter_list
  end

  def rule_parameter_declaration
    rule.name(:parameter_declaration) \
      > seq[:declaration_specifiers, :declarator] & :reverse_concat_string \
      | seq[:declaration_specifiers, :abstract_declarator] & :reverse_concat_string \
      | seq[:declaration_specifiers]
  end

  def rule_abstract_declarator
    rule.name(:abstract_declarator) \
      > seq[:pointer] \
      | seq[:direct_abstract_declarator] \
      | seq[:pointer, :direct_abstract_declarator] & :reverse_concat_string
  end

  def rule_direct_abstract_declarator
    rule.name(:direct_abstract_declarator) \
      > seq['(', :abstract_declarator, ')'] \
      | seq['[', ']'] & :direct_abstract_array \
      | seq['[', :constant_expression, ']'] & :direct_abstract_sized_array \
      | seq[:direct_abstract_declarator, '[', ']'] & :direct_array \
      | seq[:direct_abstract_declarator, '[', :constant_expression, ']'] & :direct_sized_array \
      | seq['(', ')'] & :direct_abstract_function \
      | seq['(', :parameter_type_list, ')'] & :direct_abstract_function_param \
      | seq[:direct_abstract_declarator, '(', ')'] & :direct_function \
      | seq[:direct_abstract_declarator, '(', :parameter_type_list, ')'] & :direct_function_param
  end
  def direct_abstract_array(v) "array[] of" end
  def direct_abstract_sized_array(v) "array[#{v[2]}] of" end
  def direct_abstract_function_param(v) "function(#{v[2]}) returning" end
  def direct_abstract_function(v) "function() returning" end

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
        puts "syntax error on #{parser.token_value.inspect}."
      end
    end
  end
end

PrettyANSICDeclaration.new.run

