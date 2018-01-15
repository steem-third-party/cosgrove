require 'test_helper'

class Cosgrove::AccountTest < Cosgrove::Test
  def setup
    @account = Cosgrove::Account.new('inertia')
  end
  
  def test_hidden
    refute @account.hidden?
  end
  
  def test_novote
    refute @account.novote?
  end
  
  def test_add_discord_id
    # Should refute because accounts.yml not set in tests.
    refute @account.add_discord_id(122370092229984256)
  end
  
  def test_memo_key
    assert_equal 'xevak-ganuf-nisix', @account.memo_key(122370092229984256)
  end
  
  def test_find_by_memo_key
    refute Cosgrove::Account.find_by_memo_key('key', 'secure')
  end
  
  def test_chain_account
    VCR.use_cassette('account_chain_account', record: VCR_RECORD_MODE) do
      assert_equal 'inertia', @account.chain_account.name
    end
  end
  
  def test_yml
    assert Cosgrove::Account.send(:yml)
  end
end
