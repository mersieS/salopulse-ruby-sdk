require_relative 'lib/salopulse/version'

Gem::Specification.new do |spec|
  spec.name        = 'salopulse'
  spec.version     = Salopulse::VERSION
  spec.authors     = ['Salih İmran Büker']
  spec.email       = ['salihimranbuker44@gmail.com']
  spec.summary     = 'Ruby SDK for Salopulse APM platform'
  spec.description = 'Automatic SQL, error, and HTTP performance telemetry for Ruby applications. Captures ActiveRecord queries, exceptions, and Rack request performance with zero-config setup for Rails.'
  spec.homepage    = 'https://github.com/mersieS/salopulse-ruby-sdk'
  spec.license     = 'MIT'
  spec.required_ruby_version = '>= 3.0'

  spec.metadata = {
    'homepage_uri' => 'https://github.com/mersieS/salopulse-ruby-sdk',
    'source_code_uri' => 'https://github.com/mersieS/salopulse-ruby-sdk',
    'changelog_uri' => 'https://github.com/mersieS/salopulse-ruby-sdk/blob/main/CHANGELOG.md',
    'bug_tracker_uri' => 'https://github.com/mersieS/salopulse-ruby-sdk/issues',
    'rubygems_mfa_required' => 'true'
  }

  spec.files = Dir['lib/**/*.rb', 'README.md', 'CHANGELOG.md', 'LICENSE']
  spec.require_paths = ['lib']

  spec.add_development_dependency 'activesupport', '>= 7.0'
  spec.add_development_dependency 'rake', '~> 13.0'
  spec.add_development_dependency 'rspec', '~> 3.12'
  spec.add_development_dependency 'webmock', '~> 3.18'
end
