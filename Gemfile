# frozen_string_literal: true

source 'https://rubygems.org'

# Specify your gem's dependencies in filterable.gemspec
gemspec

gem 'irb'
gem 'rake', '~> 13.0'

gem 'rspec', '~> 3.0'

# Curated dev/CI tooling (rubocop, reek, flog, flay, simplecov, undercover,
# yard, yardstick, …) with the pins the fluence-eu/ci-workflows reusables
# expect. Bump with `bundle update fluence-ci-tools`.
source 'https://rubygems.pkg.github.com/fluence-eu' do
  gem 'fluence-ci-tools', require: false
end

# Test harness only (not runtime deps): in-memory DB, ActionController::Parameters
# for the duck-typed params path, and railties to exercise the Railtie auto-include.
gem 'actionpack', '>= 7.1'
gem 'railties', '>= 7.1'
gem 'sqlite3', '>= 2.1'
