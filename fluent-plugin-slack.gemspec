# encoding: utf-8
$:.push File.expand_path('../lib', __FILE__)

Gem::Specification.new do |gem|
  gem.name        = "fluent-plugin-slack"
  gem.description = "fluent Slack plugin"
  gem.homepage    = "https://github.com/sowawa/fluent-plugin-slack"
  gem.license     = "Apache-2.0"
  gem.summary     = gem.description
  gem.version     = File.read("VERSION").strip
  gem.authors     = ["Keisuke SOGAWA", "Naotoshi Seo"]
  gem.email       = ["keisuke.sogawa@gmail.com", "sonots@gmail.com"]
  gem.has_rdoc    = false
  gem.files       = `git ls-files`.split("\n")
  gem.test_files  = `git ls-files -- {test,spec,features}/*`.split("\n")
  gem.executables = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  gem.require_paths = ['lib']

  gem.add_dependency "fluentd", ">= 0.10.8"

  gem.add_development_dependency "rake", ">= 10.1.1"
  gem.add_development_dependency "rr", ">= 1.0.0"
  gem.add_development_dependency "pry"
  gem.add_development_dependency "pry-nav"
  gem.add_development_dependency "test-unit", "~> 3.0.2"
  gem.add_development_dependency "test-unit-rr", "~> 1.0.3"
  gem.add_development_dependency "dotenv"
end
