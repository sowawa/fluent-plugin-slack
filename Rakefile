#!/usr/bin/env rake
require "bundler/gem_tasks"

require 'rake/testtask'
Rake::TestTask.new(:test) do |test|
  test.libs << 'lib' << 'test'
  test.pattern = 'test/**/test_*.rb'
  test.verbose = true
end
task :default => :test

desc 'Open an irb session preloaded with the gem library'
task :console do
    sh 'irb -rubygems -I lib'
end
task :c => :console
