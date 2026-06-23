# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec)

require 'rubocop/rake_task'

RuboCop::RakeTask.new

# Doc tasks are optional: a slim install (or a production deploy) may
# omit yard/yardstick, and the YAML config may be edited or missing
# transiently. Guard the whole block so a doc-side failure never takes
# down `rake spec` or `rake rubocop`.
begin
  require 'yard'
  require 'yard/rake/yardoc_task'
  require 'yardstick/rake/measurement'
  require 'yardstick/rake/verify'
rescue LoadError
  # yard / yardstick absent — skip doc tasks silently.
else
  require 'yaml'
  yardstick_options =
    if File.exist?('.yardstick.yml')
      YAML.load_file('.yardstick.yml') || {}
    else
      {}
    end

  namespace :doc do
    YARD::Rake::YardocTask.new(:build) do |t|
      t.stats_options = ['--list-undoc']
    end

    desc 'Print YARD documentation coverage (presence)'
    task :stats do
      sh 'bundle exec yard stats --list-undoc'
    end

    Yardstick::Rake::Measurement.new(:measure, yardstick_options) do |m|
      m.output = 'doc/yardstick_report.txt'
    end

    Yardstick::Rake::Verify.new(:verify, yardstick_options)
  end

  desc 'Alias for doc:build'
  task doc: 'doc:build'
end

task default: %i[spec rubocop]
