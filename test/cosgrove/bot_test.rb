require 'test_helper'

class Cosgrove::BotTest < Cosgrove::Test
  def setup
    options = {
      name: 'CosgroveBot',
      log_mode: :debug,
      token: 'token',
      client_id: 'client_id',
      prefix: '$',
    }
    
    @bot = Cosgrove::Bot.new(options)
    @mock_event = MockEvent.new(bot: @bot)
  end
  
  def test_version
    result = @bot.simple_execute('version', @mock_event)
    refute_nil result
  end
end
