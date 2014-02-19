# encoding: utf-8
$:.push File.expand_path('../lib', __FILE__)

Gem::Specification.new do |gem|
  gem.name        = "fluent-plugin-slack"
  gem.description = "fluent Slack plugin"
  gem.homepage    = "https://github.com/sowawa/fluent-plugin-slack"
  gem.summary     = gem.description
  gem.version     = File.read("VERSION").strip
  gem.authors     = ["Keisuke SOGAWA"]
  gem.email       = "keisuke.sogawa@gmail.com"
  gem.has_rdoc    = false
  gem.files       = `git ls-files`.split("\n")
  gem.test_files  = `git ls-files -- {test,spec,features}/*`.split("\n")
  gem.executables = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  gem.require_paths = ['lib']

  gem.add_dependency "fluentd", ">= 0.10.8"
  gem.add_dependency "slackr",  ">= 0.0.2"
  gem.add_dependency "activesupport", ">=3.2.16"
  gem.add_dependency "tzinfo", ">=0.3.38"

  gem.add_development_dependency "rake", ">= 0.9.2"
  gem.add_development_dependency "simplecov", ">= 0.5.4"
  gem.add_development_dependency "rr", ">= 1.0.0"
  gem.add_development_dependency "pry"
end
