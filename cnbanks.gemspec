# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'cnbanks/version'

Gem::Specification.new do |spec|
  spec.name          = 'cnbanks'
  spec.version       = CNBanks::VERSION
  spec.authors       = ['songjiz']
  spec.email         = ['lekyzsj@gmail.com']

  spec.summary       = %q{China Bank Codes}
  spec.description   = %q{China Bank Codes}
  spec.homepage      = 'https://github.com/songjiz/cnbanks'

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = 'bin'
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'sqlite3', '~> 1.3'
  spec.add_dependency 'oga', '~> 2.10'
  spec.add_dependency 'http', '~> 2.2'
  spec.add_dependency 'ruby-pinyin', '~> 0.5.0'

  spec.add_development_dependency 'bundler', '~> 1.14'
  spec.add_development_dependency 'rake', '~> 10.0'
end
