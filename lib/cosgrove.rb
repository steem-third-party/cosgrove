require 'rubygems'
require 'bundler/setup'
require 'yaml'
# require 'pry'

Bundler.require

SteemData.load

module Cosgrove
  require 'cosgrove/version'
  require 'cosgrove/config'
  require 'cosgrove/utils'
  require 'cosgrove/bot'
end
