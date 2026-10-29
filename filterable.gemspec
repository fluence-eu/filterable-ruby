# frozen_string_literal: true

require_relative 'lib/filterable/version'

Gem::Specification.new do |spec|
  spec.name = 'filterable'
  spec.version = Filterable::VERSION
  spec.authors = ['Jonathan PHILIPPE']
  spec.email = ['jphilippe@fluence.eu']

  spec.summary = 'Declarative, whitelisted query filtering and ordering for ActiveRecord'
  spec.description = 'Models declare which columns are datable and sortable, then ' \
                     'filterable(params) folds whitelisted date and sort filters over the relation.'
  spec.homepage = 'https://github.com/fluence-eu/filterable-ruby'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.3.0'

  spec.metadata['allowed_push_host'] = 'https://rubygems.pkg.github.com/fluence-eu'
  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage
  spec.metadata['changelog_uri'] = 'https://github.com/fluence-eu/filterable-ruby/blob/main/CHANGELOG.md'
  spec.metadata['github_repo'] = spec.homepage
  spec.metadata['rubygems_mfa_required'] = 'true'

  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ Gemfile .gitignore .rspec spec/ .github/ .rubocop.yml])
    end
  end
  spec.require_paths = ['lib']

  spec.add_dependency 'activerecord', '>= 7.1'
  spec.add_dependency 'activesupport', '>= 7.1'
end
