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
  
  def test_help
    result = @bot.simple_execute('help', @mock_event)
    refute_nil result
  end
  
  def test_version
    result = @bot.simple_execute('version', @mock_event)
    refute_nil result
  end
  
  def test_verify
    expected_result = "No association found.  To register:\n`$register <account>`"
    
    VCR.use_cassette('command_verify_cosgrove', record: VCR_RECORD_MODE) do
      result = @bot.simple_execute('verify cosgrove', @mock_event)
      refute_nil result
      assert_equal expected_result, result
    end
  end
  
  def test_verify_empty
    expected_result = 'To create an account: https://steemit.com/enter_email?r=cosgrove'
    
    result = @bot.simple_execute('verify', @mock_event)
    refute_nil result
    assert_equal expected_result, @mock_event.responses.last
  end
end
