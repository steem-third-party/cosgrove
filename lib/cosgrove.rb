require 'rubygems'
require 'bundler/setup'
require 'yaml'
require 'action_view'
require 'radiator'
require 'awesome_print'
require 'steem_data'
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
  require 'cosgrove/upvote_job'
  require 'cosgrove/comment_job'
  require 'cosgrove/bot'
end
