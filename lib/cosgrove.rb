require 'rubygems'
require 'bundler/setup'
require 'yaml'
# require 'pry'

Bundler.require

SteemData.load

module Cosgrove
  require 'cosgrove/version'
  require 'cosgrove/agent'
  require 'cosgrove/config'
  require 'cosgrove/utils'
  require 'cosgrove/account'
  require 'cosgrove/bot'
  
  KNOWN_CHAINS = [:steem, :golos, :test]
end
