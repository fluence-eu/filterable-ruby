# frozen_string_literal: true

source 'https://rubygems.org'

# Specify your gem's dependencies in filterable.gemspec
gemspec

gem 'irb'
gem 'rake', '~> 13.0'

group :development, :test do
  gem 'rspec', '~> 3.0'
  gem 'rubocop', '~> 1.21'

  # Documentation coverage, like the other Fluence gems.
  gem 'yard', '~> 0.9', require: false

  # Test harness only: an in-memory database to run the filters against, and
  # ActionController::Parameters to prove the duck-typed params path. Neither is
  # a runtime dependency of the gem.
  gem 'actionpack', '>= 7.1'
  gem 'sqlite3', '>= 2.1'

  gem 'simplecov', require: false
end
