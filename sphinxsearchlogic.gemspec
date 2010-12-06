# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{sphinxsearchlogic}
  s.version = "0.9.3"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Joost Hietbrink"]
  s.date = %q{2009-08-25}
  s.description = %q{Searchlogic provides common named scopes and object based searching for ActiveRecord.}
  s.email = %q{joost@joopp.com}
  s.extra_rdoc_files = [
    "MIT-LICENSE",
    "README.rdoc",
    "CHANGELOG.rdoc"
  ]
  s.files = [
     "CHANGELOG.rdoc",
     "MIT-LICENSE",
     "README.rdoc",
     "VERSION.yml",
     "init.rb",
     "lib/sphinxsearchlogic.rb",
     "lib/rails_helpers.rb",
     "rails/init.rb",
     "test/sphinxsearchlogic_test.rb",
     "test/test_helper.rb"
  ]
  s.homepage = %q{http://github.com/joost/sphinxsearchlogic}
  s.has_rdoc = true
  s.rdoc_options = ["--charset=UTF-8"]
  s.require_paths = ["lib"]
  s.rubyforge_project = %q{sphinxsearchlogic}
  s.rubygems_version = %q{1.3.5}
  s.summary = %q{Sphinxsearchlogic is for ThinkingSphinx what Searchlogic is for ActiveRecord.. or at least something similar.}
  s.test_files = [
    "test/sphinxsearchlogic_test.rb",
    "test/test_helper.rb"
  ]

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 3

    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<activerecord>, [">= 2.0.0"])
    else
      s.add_dependency(%q<activerecord>, [">= 2.0.0"])
    end
  else
    s.add_dependency(%q<activerecord>, [">= 2.0.0"])
  end
end
