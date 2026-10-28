# frozen_string_literal: true

source 'https://rubygems.org'

# Specify your gem's dependencies in filterable.gemspec
gemspec

gem 'irb'
gem 'rake', '~> 13.0'

gem 'rspec', '~> 3.0'

# Curated dev/CI tooling (rubocop, reek, flog, flay, simplecov, undercover,
# yard, yardstick, …) with the pins the fluence-eu/ci-workflows reusables
# expect. Bump with `bundle update guardian-ci`.
gem 'guardian-ci', require: false

# Test harness only (not runtime deps): in-memory DB, ActionController::Parameters
# for the duck-typed params path, railties to exercise the Railtie auto-include,
# and activestorage for the has_one_attached association-target integration spec.
gem 'actionpack', '>= 7.1'
gem 'activestorage', '>= 7.1'
gem 'railties', '>= 7.1'
gem 'sqlite3', '>= 2.1'
