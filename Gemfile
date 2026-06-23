# frozen_string_literal: true

source 'https://rubygems.org'

# Specify your gem's dependencies in filterable.gemspec
gemspec

gem 'irb'
gem 'rake', '~> 13.0'

gem 'rspec', '~> 3.0'

gem 'rubocop', '~> 1.21'

# Code quality (advisory): reek = design smells, flog = complexity, flay = duplication.
gem 'flay', '~> 2.14', require: false
gem 'flog', '~> 4.9', require: false
gem 'reek', '~> 6.5', require: false

# Coverage: simplecov computes it, undercover flags uncovered diffs.
gem 'simplecov', '~> 0.22.0', require: false
gem 'undercover', '~> 0.8.5', require: false

# Documentation coverage: yard (presence) + yardstick (quality threshold).
gem 'yard', '~> 0.9', require: false
gem 'yardstick', '~> 0.9', require: false

# Test harness only (not runtime deps): in-memory DB, ActionController::Parameters
# for the duck-typed params path, and railties to exercise the Railtie auto-include.
gem 'actionpack', '>= 7.1'
gem 'railties', '>= 7.1'
gem 'sqlite3', '>= 2.1'
