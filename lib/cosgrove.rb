require 'rubygems'
require 'bundler/setup'
require 'yaml'
# require 'pry'

Bundler.require

module Cosgrove
  require 'cosgrove/version'
  require 'cosgrove/config'
  require 'cosgrove/bot'
end
