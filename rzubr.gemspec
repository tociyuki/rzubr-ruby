# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'rzubr/version'

Gem::Specification.new do |spec|
  spec.name          = "rzubr"
  spec.version       = Rzubr::VERSION
  spec.authors       = ["MIZUTANI Tociyuki"]
  spec.email         = ["tociyuki@gmail.com"]
  spec.summary       = %q{Toy LALR(1) parser}
  spec.description   = %q{}
  spec.homepage      = "https://github.com/tociyuki/rzubr-ruby"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.5"
  spec.add_development_dependency "rake"
end

