require 'test_helper'

class Cosgrove::BotTest < Cosgrove::Test
  def test_help
    result = bot.simple_execute('help', mock_event)
    refute_nil result
  end
  
  def test_version
    result = bot.simple_execute('version', mock_event)
    refute_nil result
  end
  
  def test_verify
    expected_result = "No association found.  To register:\n`$register <account>`"
    
    VCR.use_cassette('command_verify_cosgrove', record: VCR_RECORD_MODE) do
      result = bot.simple_execute('verify cosgrove', mock_event)
      refute_nil result
      assert_equal expected_result, result
    end
  end
  
  def test_verify_bogus
    expected_result = "STEEM account `bogus` has not been registered with any Discord account.  To register:\n`$register bogus`"
    
    VCR.use_cassette('command_verify_cosgrove', record: VCR_RECORD_MODE) do
      result = bot.simple_execute('verify bogus', mock_event)
      refute_nil result
      assert_equal expected_result, result
    end
  end
  
  def test_register
    expected_result = 'Try again later.'
    
    VCR.use_cassette('command_register_cosgrove', record: VCR_RECORD_MODE) do
      bot.simple_execute('register cosgrove', mock_event)
      result = mock_event.responses.last
      refute_nil result
      skip 'Mongo is behind.' if result =~ /Mongo is behind.*/
      assert_equal expected_result, result
    end
  end
  
  def test_verify_empty
    expected_result = 'To create an account: https://steemit.com/enter_email?r=cosgrove'
    
    result = bot.simple_execute('verify', mock_event)
    refute_nil result
    assert_equal expected_result, mock_event.responses.last
  end
  
  def test_slap
    result = bot.simple_execute('slap dan', mock_event)
    refute_nil result
  end
  
  def test_slap_no_target
    result = bot.simple_execute('slap', mock_event)
    refute_nil result
  end
end
