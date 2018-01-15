require 'test_helper'

class Cosgrove::MarketTest < Cosgrove::Test
  include Cosgrove::Market
  
  def setup
  end
  
  def test_price_feed
    VCR.use_cassette('market_price_feed', record: VCR_RECORD_MODE) do
      assert price_feed
    end
  end
  
  def test_gold_price
    VCR.use_cassette('market_gold_price', record: VCR_RECORD_MODE) do
      assert gold_price
    end
  end
  
  def test_market_data
    VCR.use_cassette('market_market_data', record: VCR_RECORD_MODE) do
      assert market_data
    end
  end
  
  def test_mvests
    VCR.use_cassette('market_mvests', record: VCR_RECORD_MODE) do
      assert mvests
    end
  end
  
  def test_mvests_account_name
    VCR.use_cassette('market_mvests_account_name', record: VCR_RECORD_MODE) do
      assert mvests(:steem, ['inertia'])
      assert mvests(:steem, ['inertia186'])
      assert mvests(:steem, ['a-a']) # vesting_shares.amount == 0
      assert mvests(:steem, ['banjo']) # vesting_shares.amount == 0
    end
  end
  
  def test_mvests_mutiple
    VCR.use_cassette('market_mvests_mutiple', record: VCR_RECORD_MODE) do
      assert mvests(:steem, ['inertia', 'inertia186'])
      assert mvests(:steem, ['banjo', 'drotto'])
    end
  end
  
  def test_mvests_wildcard
    VCR.use_cassette('market_mvests_wildcard', record: VCR_RECORD_MODE) do
      assert mvests(:steem, ['inertia*'])
    end
  end
  
  def test_mvests_golos
    VCR.use_cassette('market_mvests_golos', record: VCR_RECORD_MODE) do
      assert mvests(:golos)
    end
  end
  
  def test_mvests_golos_account_name
    VCR.use_cassette('market_mvests_golos_account_name', record: VCR_RECORD_MODE) do
      assert mvests(:golos, ['inertia'])
    end
  end
  
  def test_mvests_test
    skip 'No public test nodes.'
    
    VCR.use_cassette('market_mvests_test', record: VCR_RECORD_MODE) do
      assert mvests(:test)
    end
  end
  
  def test_rewardpool
    VCR.use_cassette('market_rewardpool', record: VCR_RECORD_MODE) do
      assert rewardpool
    end
  end
  
  def test_rewardpool_golos
    VCR.use_cassette('market_rewardpool_golos', record: VCR_RECORD_MODE) do
      assert rewardpool(:golos)
    end
  end
  
  def test_ticker
    VCR.use_cassette('market_ticker', record: VCR_RECORD_MODE) do
      assert ticker
    end
  end
  
  def test_promoted
    VCR.use_cassette('market_promoted', record: VCR_RECORD_MODE) do
      assert promoted
    end
  end
  
  def test_supply
    VCR.use_cassette('market_supply', record: VCR_RECORD_MODE) do
      assert supply(:steem)
    end
  end
  
  def test_supply_golos
    VCR.use_cassette('market_supply_golos', record: VCR_RECORD_MODE) do
      assert supply(:golos)
    end
  end
  
  def test_mvests_sum
    VCR.use_cassette('market_mvests_sum', record: VCR_RECORD_MODE) do
      assert mvests_sum(chain: :steem, account_names: ['inertia'])
    end
  end
  
  def test_mvests_sum_golos
    VCR.use_cassette('market_mvests_sum_golos', record: VCR_RECORD_MODE) do
      assert mvests_sum(chain: :golos, account_names: ['inertia'])
    end
  end
  
  def test_debt_exchange_rate
    VCR.use_cassette('market_debt_exchange_rate', record: VCR_RECORD_MODE) do
      assert debt_exchange_rate
    end
  end
  
  def test_debt_exchange_rate_golos
    VCR.use_cassette('market_debt_exchange_rate_golos', record: VCR_RECORD_MODE) do
      assert debt_exchange_rate(:golos)
    end
  end
  
  def test_apr
    VCR.use_cassette('market_apr', record: VCR_RECORD_MODE) do
      assert apr
    end
  end
  
  def test_effective_apr
    VCR.use_cassette('market_effective_apr', record: VCR_RECORD_MODE) do
      assert effective_apr
    end
  end
  
  def test_effective_price
    VCR.use_cassette('market_effective_price', record: VCR_RECORD_MODE) do
      assert effective_price
    end
  end
  
  def test_effective_price_golos
    VCR.use_cassette('market_effective_price_golos', record: VCR_RECORD_MODE) do
      assert effective_price(:golos)
    end
  end
end
