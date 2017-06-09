$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)

if ENV["HELL_ENABLED"] || ENV['CODECLIMATE_REPO_TOKEN']
  require 'simplecov'
  # if ENV['CODECLIMATE_REPO_TOKEN']
  #   require "codeclimate-test-reporter"
  #   SimpleCov.start CodeClimate::TestReporter.configuration.profile
  #   CodeClimate::TestReporter.start
  # else
    SimpleCov.start
  # end
  SimpleCov.merge_timeout 3600
end

require 'cosgrove'

require 'minitest/autorun'

require 'webmock/minitest'
require 'vcr'
require 'yaml'
require 'pry'
require 'typhoeus/adapters/faraday'
require 'securerandom'

if !!ENV['VCR']
  VCR.configure do |c|
    c.cassette_library_dir = 'test/fixtures/vcr_cassettes'
    c.hook_into :webmock
  end
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
  WebMock.disable_net_connect!(allow_localhost: false, allow: 'codeclimate.com:443')
end

class MockChannel
  attr_accessor :topic
  
  def initialize
    @topic = nil
  end
  
  def name
    'test_channel'
  end
  
  def start_typing
  end
end

class MockAuthor
  attr_accessor :id, :resolve_id
  
  def initialize(options = {})
    @id = options[:id] || 'test_id'
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

class Cosgrove::Test < MiniTest::Test
  def save filename, result
    f = File.open("#{File.dirname(__FILE__)}/support/#{filename}", 'w+')
    f.write(result)
    f.close
  end
end
