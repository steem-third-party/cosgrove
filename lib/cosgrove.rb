require 'rubygems'
require 'bundler/setup'
require 'yaml'
require 'active_support'
require 'action_view'
require 'radiator'
require 'awesome_print'
# require 'pry' # for binding.pry

Bundler.require

defined? Thread.report_on_exception and Thread.report_on_exception = true

module Cosgrove
  PWD = Dir.pwd.freeze
  KNOWN_CHAINS = [:steem, :test, :hive]
  
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
  require 'cosgrove/find_communities_job'
  require 'cosgrove/bot'
end
