# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'furi/version'

Gem::Specification.new do |spec|
  spec.name          = "furi"
  spec.version       = Furi::VERSION
  spec.authors       = ["Bogdan Gusiev"]
  spec.email         = ["agresso@gmail.com"]
  spec.summary       = %q{Make URI processing as easy as it should be}
  spec.description   = %q{The phylosophy of this gem is to make any URI modification or parsing operation to take only one line of code and never more}
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.7"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "pry-byebug"
end
