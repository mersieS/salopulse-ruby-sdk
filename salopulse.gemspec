require_relative "lib/salopulse/version"

Gem::Specification.new do |spec|
  spec.name        = "salopulse"
  spec.version     = Salopulse::VERSION
  spec.authors     = ["Salopulse"]
  spec.email       = ["support@salopulse.com"]
  spec.summary     = "Ruby SDK for Salopulse APM platform"
  spec.description = "Automatic SQL, error, and HTTP performance telemetry for Ruby applications."
  spec.homepage    = "https://salopulse.com"
  spec.license     = "MIT"
  spec.required_ruby_version = ">= 3.0"

  spec.files = Dir["lib/**/*.rb", "README.md", "CHANGELOG.md", "LICENSE"]
  spec.require_paths = ["lib"]

  spec.add_development_dependency "rspec", "~> 3.12"
  spec.add_development_dependency "webmock", "~> 3.18"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "activesupport", ">= 7.0"
end
