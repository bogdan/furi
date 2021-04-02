# frozen_string_literal: true

require_relative "lib/furi/version"

Gem::Specification.new do |spec|
  spec.name          = "furi"
  spec.version       = Furi::VERSION
  spec.authors       = ["Bogdan Gusiev"]
  spec.email         = ["agresso@gmail.com"]
  spec.summary       = %q{Make URI processing as easy as it should be}
  spec.description   = %q{The philosophy of this gem is to make any URI modification or parsing operation to take only one line of code and never more}
  spec.homepage      = "https://github.com/bogdan/furi"
  spec.license       = "MIT"
  spec.required_ruby_version = Gem::Requirement.new(">= 2.4.0")

  spec.metadata["allowed_push_host"] = "https://rubygems.org"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{\A(?:test|spec|features)/}) }
  end
  spec.require_paths = ["lib"]
end
