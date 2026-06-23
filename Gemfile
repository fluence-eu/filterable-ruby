# frozen_string_literal: true

source 'https://rubygems.org'

# Specify your gem's dependencies in filterable.gemspec
gemspec

gem 'irb'
gem 'rake', '~> 13.0'

gem 'rspec', '~> 3.0'

gem 'rubocop', '~> 1.21'

# Code quality (advisory): reek = design smells, flog = complexity, flay = duplication.
# Pinned to ~> X.Y so tool upgrades don't shift the baseline/delta numbers
# the codequality CI sticky comment compares against.
gem 'flay', '~> 2.14', require: false
gem 'flog', '~> 4.9', require: false
gem 'reek', '~> 6.5', require: false

gem 'simplecov', require: false
gem 'undercover', require: false

# Documentation coverage: yard measures presence (stats), yardstick
# measures quality (tags, summaries, enforced threshold). Pinned to
# ~> 0.9 so tool upgrades don't shift the docs CI baseline/delta numbers.
gem 'yard', '~> 0.9', require: false
gem 'yardstick', '~> 0.9', require: false

# Test harness only: an in-memory database to run the filters against,
# ActionController::Parameters to prove the duck-typed params path, and
# railties to exercise the Railtie auto-include. None is a runtime dependency.
gem 'actionpack', '>= 7.1'
gem 'railties', '>= 7.1'
gem 'sqlite3', '>= 2.1'
