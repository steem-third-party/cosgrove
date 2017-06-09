# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'cosgrove/version'

Gem::Specification.new do |spec|
  spec.name = 'cosgrove'
  spec.version = Cosgrove::VERSION
  spec.authors = ['Anthony Martin']
  spec.email = ['cosgrove@martin-studio.com']

  spec.summary = %q{Cosgrove Discord Bo t}
  spec.description = %q{STEEM centric Discord bot.}
  spec.homepage = 'https://github.com/steem-third-party/cosgrove'
  spec.license = 'CC0 1.0'

  spec.files = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test)/}) }
  spec.require_paths = ['lib']

  spec.add_development_dependency 'bundler', '~> 1.11'
  spec.add_development_dependency 'rake', '~> 11.2.2'
  spec.add_development_dependency 'minitest'
  spec.add_development_dependency 'minitest-line'
  spec.add_development_dependency 'webmock'
  spec.add_development_dependency 'vcr'
  spec.add_development_dependency 'faraday'
  spec.add_development_dependency 'typhoeus'
  spec.add_development_dependency 'simplecov'
  # spec.add_development_dependency 'codeclimate-test-reporter'
  spec.add_development_dependency 'yard'
  spec.add_development_dependency 'byebug'
  spec.add_development_dependency 'pry'
  spec.add_development_dependency 'awesome_print'

  spec.add_dependency 'radiator'
  spec.add_dependency 'steemdata-rb'
  spec.add_dependency 'discordrb'
  spec.add_dependency 'ai4r'
  spec.add_dependency 'mongoid'
  spec.add_dependency 'ruby-cleverbot-api'
  spec.add_dependency 'steem-slap'
  spec.add_dependency 'activeview'
  spec.add_dependency 'rdiscount'
  spec.add_dependency 'phantomjs'
  spec.add_dependency 'mechanize'
  spec.add_dependency 'wolfram-alpha'
  spec.add_dependency 'rmagick'
end
