# frozen_string_literal: true

require_relative "lib/rspec/risky/version"

Gem::Specification.new do |spec|
  spec.name = "rspec-risky"
  spec.version = RSpec::Risky::VERSION
  spec.authors = ["Yudai Takada"]
  spec.email = ["t.yudai92@gmail.com"]

  spec.summary = "Runtime risky-test detection for RSpec."
  spec.description = "Detects RSpec examples that execute no expectations or write unexpected stdout/stderr output."
  spec.homepage = "https://github.com/ydah/rspec-risky"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "#{spec.homepage}/tree/main"

  # Uncomment the line below to require MFA for gem pushes.
  # This helps protect your gem from supply chain attacks by ensuring
  # no one can publish a new version without multi-factor authentication.
  # See: https://guides.rubygems.org/mfa-requirement-opt-in/
  # spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir.chdir(__dir__) do
    Dir["exe/*", "lib/**/*.rb", "sig/**/*.rbs", "LICENSE.txt", "README.md"]
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "rspec-core", "~> 3.13"
  spec.add_dependency "rspec-expectations", "~> 3.13"
  spec.add_dependency "rspec-mocks", "~> 3.13"
  spec.add_dependency "minitest", ">= 5.0"
end
