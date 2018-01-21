require 'rubygems'
require 'bundler/setup'
require 'yaml'
require 'action_view'
require 'radiator'
require 'awesome_print'
require 'steem_data'
require 'steem_api'
require 'golos_cloud'
# require 'irb' # for binding.irb
# require 'pry' # for binding.pry

Bundler.require

defined? Thread.report_on_exception and Thread.report_on_exception = true

SteemData.load

# This will cause a nil to be returned instead of raising an error, allowing us
# to fall back to SteemApi and/or RPC.
Mongoid.raise_not_found_error = false

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
