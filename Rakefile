# frozen_string_literal: true

require 'rubocop/rake_task'
require 'minitest/test_task'

RuboCop::RakeTask.new do |task|
  task.options = %w[--config .rubocop.yml]
  task.formatters = ['github'] if ENV['GITHUB_ACTIONS']
end

Minitest::TestTask.create

task default: %i[rubocop test]

desc 'Run console'
task :console do
  sh(Gem.ruby, 'bin/console')
end
