# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'cosgrove/version'

Gem::Specification.new do |spec|
  spec.name = 'cosgrove'
  spec.version = Cosgrove::VERSION
  spec.authors = ['Anthony Martin']
  spec.email = ['cosgrove@martin-studio.com']

  spec.summary = %q{Cosgrove Discord Bot}
  spec.description = %q{STEEM centric Discord bot.}
  spec.homepage = 'https://github.com/steem-third-party/cosgrove'
  spec.license = 'CC0-1.0'

  spec.files = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test)/}) }
  spec.require_paths = ['lib']

  spec.add_development_dependency 'bundler', '~> 2.0', '>= 2.0.1'
  spec.add_development_dependency 'rake', '~> 12.1', '>= 12.1.0'
  spec.add_development_dependency 'minitest-proveit', '~> 1.0', '>= 1.0.0'
  spec.add_development_dependency 'minitest', '~> 5.10', '>= 5.10.3'
  spec.add_development_dependency 'minitest-line', '~> 0.6', '>= 0.6.4'
  spec.add_development_dependency 'webmock', '~> 3.0', '>= 3.0.1'
  spec.add_development_dependency 'vcr', '~> 4.0', '>= 4.0.0'
  spec.add_development_dependency 'simplecov', '~> 0.11', '>= 0.11.2'
  spec.add_development_dependency 'yard', '~> 0.9', '>= 0.9.19'

  spec.add_dependency 'radiator', '~> 0.4', '>= 0.4.6'
  spec.add_dependency 'steem_api', '~> 1.1', '>= 1.1.3'
  spec.add_dependency 'discordrb', '~> 3.2', '>= 3.2.1'
  spec.add_dependency 'ai4r', '~> 1.13', '>= 1.13'
  spec.add_dependency 'steem-slap', '~> 0.0', '>= 0.0.2'
  spec.add_dependency 'activesupport', '~> 5.1', '>= 5.1.1'
  spec.add_dependency 'railties', '~> 5.1', '>= 5.1.1'
  spec.add_dependency 'rdiscount', '~> 2.2', '>= 2.2.0.1'
  spec.add_dependency 'phantomjs', '~> 2.1', '>= 2.1.1.0'
  spec.add_dependency 'mechanize', '~> 2.7', '>= 2.7.5'
  spec.add_dependency 'wolfram-alpha', '~> 0.3', '>= 0.3.1'
  spec.add_dependency 'rmagick', '~> 3.1', '>= 3.1.0'
  spec.add_dependency 'awesome_print', '~> 1.7', '>= 1.7.0'
end
