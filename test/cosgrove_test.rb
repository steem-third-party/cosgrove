require 'test_helper'

module Cosgrove
  class CosgroveTest < Cosgrove::Test
    def setup
    end
    
    def test_known_chains
      assert_equal %i(steem test), Cosgrove::KNOWN_CHAINS
    end
  end
end
