require 'rubygems'
require 'bundler/setup'
require 'yaml'
require 'action_view'
# require 'pry'

Bundler.require

SteemData.load

module Cosgrove
  PWD = Dir.pwd.freeze
  KNOWN_CHAINS = [:steem, :golos, :test]
  
  require 'cosgrove/version'
  require 'cosgrove/phantomjs'
  require 'cosgrove/agent'
  require 'cosgrove/config'
  require 'cosgrove/utils'
  require 'cosgrove/account'
  require 'cosgrove/support'
  require 'cosgrove/market'
  require 'cosgrove/bot'
end
