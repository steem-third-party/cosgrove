$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)

if ENV["HELL_ENABLED"]
  require 'minitest/benchmark'
  require 'simplecov'
  SimpleCov.start
  SimpleCov.merge_timeout 3600
end

require 'minitest/autorun'
require 'webmock/minitest'
require 'vcr'
require 'yaml'
require 'securerandom'
require 'cosgrove'

# Just for testing.
COSGROVE_DISCORD_ID = 273608642232582144

VCR.configure do |c|
  c.cassette_library_dir = 'test/fixtures/vcr_cassettes'
  c.hook_into :webmock
end

if ENV["HELL_ENABLED"]
  require "minitest/hell"
  
  class Minitest::Test
    # See: https://gist.github.com/chrisroos/b5da6c6a37ac8af5fe78
    parallelize_me! unless defined? WebMock
  end
else
  require "minitest/pride"
end

if defined? WebMock 
  allow = ['codeclimate.com:443']
  WebMock.disable_net_connect!(allow_localhost: false, allow: allow)
end

class MockChannel
  attr_accessor :id, :topic
  
  def initialize(options = {})
    @topic = options[:topic]
    @id = options[:id]
  end
  
  def name
    'test_channel'
  end
  
  def start_typing
  end
  
  def pm?
    false
  end
end

class MockAuthor
  attr_accessor :id, :resolve_id
  
  def initialize(options = {})
    @id = options[:id] || COSGROVE_DISCORD_ID
    @resolve_id = options[:resolve_id] || SecureRandom.hex
  end
  
  def webhook?
    false
  end
  
  def roles
    []
  end
end

class MockEvent
  attr_accessor :bot, :command, :commands, :responses, :files, :channel, :author, :result
  
  def initialize(options = {})
    @bot = options[:bot]
    @command = nil
    @commands = []
    @responses = []
    @files = []
    @channel = options[:channel] || MockChannel.new
    @author = options[:author] || MockAuthor.new
    @result = nil
  end
  
  def command(name, &block)
    @commands << {name => block}
  end
  
  def respond(response)
    @responses << response
  end
  
  def server
    'test_server'
  end
  
  def send_file(file, caption = nil)
    @files << {file => caption}
  end
  
  def drain_into(result)
    @result = result
  end
end

module Cosgrove
  module Config
    def yml
      {
        cosgrove: {
          token: '634c3f3bdad073e963b9fdefe1c483d19d7540258aee5744b4f9d287853c422e',
          client_id: COSGROVE_DISCORD_ID,
          secure: '987d25308f27446e37238e1189c35e899b3f24bb1a8fcad0ab57a25c6fd6075b',
          upvote_weight: 'upvote_rules',
          upvote_rules: {
            channels: {
              default: {
                upvote_weight: '10.00 %'
              },
              specific_channel: {
                channel_id: 65442882692710,
                upvote_weight: '100.00 %',
                disable_comment_voting: true
              },
              another_specific_channel: {
                channel_id: 92893087564620,
                upvote_weight: '33.33 %'
              }
            }
          }
        },
        chain: {
          steem_account: 'cosgrove',
          steem_posting_wif: '5ffaed497ad3e693efe3139e63fcc2cdc15151046b99dc4d78',
          steem_api_url: 'https://api.steemit.com',
          test_api_url: 'https://test.steem.ws',
        },
        discord: {
          log_mode: 'info'
        }
      }
    end
  end
end

module Cosgrove
  class Account
    def self.yml
      {
        'steem' => {
          'cosgrove' => {
            'discord_ids' => [COSGROVE_DISCORD_ID]
          }
        }
      }
    end
  end
end

class Cosgrove::Test < MiniTest::Test
  VCR_RECORD_MODE = (ENV['VCR_RECORD_MODE'] || 'once').to_sym
  # VCR_RECORD_MODE = :new_episodes
  
  def bot
    options = {
      name: 'CosgroveBot',
      log_mode: :debug,
      token: 'token',
      client_id: 'client_id',
      prefix: '$',
    }
    
    @bot ||= Cosgrove::Bot.new(options)
  end
  
  def mock_event
    @mock_event ||= MockEvent.new(bot: bot)
  end

  def save filename, result
    f = File.open("#{File.dirname(__FILE__)}/support/#{filename}", 'w+')
    f.write(result)
    f.close
  end
end
