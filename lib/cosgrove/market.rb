module Cosgrove
  module Market
    include Cosgrove::Support
    include ActionView::Helpers::NumberHelper

    def price_feed(chain = :steem)
      feed_history = api(chain).get_feed_history.result
      base_per_mvest = api(chain).steem_per_mvest
      
      current_median_history = feed_history.current_median_history
      base = current_median_history.base
      base = base.split(' ').first.to_f
      quote = current_median_history.quote
      quote = quote.split(' ').first.to_f
      
      base_per_debt = (base / quote) * base_per_mvest
      
      [base_per_mvest, base_per_debt]
    end
    
    # https://api.vaultoro.com/#api-Basic_API-getMarkets
    def gold_price
      begin
        gold_market = JSON[open("https://api.vaultoro.com/markets").read]
        pol_usdt_btc = JSON[open("https://poloniex.com/public?command=returnOrderBook&currencyPair=USDT_BTC&depth=10").read]
        pol_usdt_btc = pol_usdt_btc['asks'].first.first.to_f
        btc_gld = gold_market['data']['LastPrice'].to_f
        
        [btc_gld, (btc_gld * pol_usdt_btc) / 1000] # btc_gld, usdt_gld_per_milli
      rescue
        [0, 0]
      end
    end
    
    def market_data
      pol_btc_steem = JSON[open("https://poloniex.com/public?command=returnOrderBook&currencyPair=BTC_STEEM&depth=10").read]
      pol_btc_sbd = JSON[open("https://poloniex.com/public?command=returnOrderBook&currencyPair=BTC_SBD&depth=10").read]
      pol_usdt_btc = JSON[open("https://poloniex.com/public?command=returnOrderBook&currencyPair=USDT_BTC&depth=10").read]
      
      pol_btc_steem = pol_btc_steem['asks'].first.first.to_f
      pol_btc_sbd = pol_btc_sbd['asks'].first.first.to_f
      pol_usdt_btc = pol_usdt_btc['asks'].first.first.to_f
      
      pol_usdt_sbd = pol_usdt_btc * pol_btc_sbd
      pol_usdt_steem = pol_usdt_btc * pol_btc_steem
      # pol_sbd_steem = pol_usdt_sbd * ( pol_usdt_btc * pol_btc_steem )
      
      btx_btc_golos = JSON[open("https://bittrex.com/api/v1.1/public/getmarketsummary?market=btc-golos").read]
      btx_btc_gbg = JSON[open("https://bittrex.com/api/v1.1/public/getmarketsummary?market=btc-gbg").read]
      btx_usdt_btc = JSON[open("https://bittrex.com/api/v1.1/public/getmarketsummary?market=usdt-btc").read]
      
      btx_btc_golos = btx_btc_golos['result'].first['Ask'].to_f
      btx_btc_gbg = btx_btc_gbg['result'].first['Ask'].to_f
      btx_usdt_btc = btx_usdt_btc['result'].first['Ask'].to_f
      
      btx_usdt_gbg = btx_usdt_btc * btx_btc_gbg
      btx_usdt_golos = btx_usdt_btc * btx_btc_golos
      # btx_gbg_golos = btx_usdt_gbg * ( btx_usdt_btc * btx_btc_golos )
      
      [pol_usdt_steem, pol_usdt_sbd, btx_usdt_golos, btx_usdt_gbg]
    end
    
    def mvests(chain = :steem, account_names = [])
      pol_usdt_steem, _pol_usdt_sbd, btx_usdt_golos, _btx_usdt_gbg = market_data
      base_per_mvest, base_per_debt = price_feed(chain)
      
      if account_names.none?
        pol_base_per_dept_as_usdt = base_per_mvest * pol_usdt_steem
        pol_base_per_dept_as_usdt = number_to_currency(pol_base_per_dept_as_usdt, precision: 3)
        
        base_per_mvest = number_with_precision(base_per_mvest, precision: 3, delimiter: ',', separator: '.')
        
        base_per_debt = if chain == :steem
          number_to_currency(base_per_debt, precision: 3)
        else
          _btc_gld, usdt_gld_per_milli = gold_price
          base_per_debt_as_usdt = base_per_debt * usdt_gld_per_milli
          base_per_debt_as_usdt = number_to_currency(base_per_debt_as_usdt, precision: 3)
          
          number_with_precision(base_per_debt, precision: 3, delimiter: ',', separator: '.')
        end
        
        # E.g. from 2016/11/25: 1 MV = 1M VESTS = 459.680 STEEM = $50.147
        return case chain
        when :steem then "`1 MV = 1M VESTS = #{base_per_mvest} STEEM = #{base_per_debt} = #{pol_base_per_dept_as_usdt} on Poloniex`"
        when :golos then "`1 MG = 1M GESTS = #{base_per_mvest} GOLOS = #{base_per_debt} GBG = #{base_per_debt_as_usdt}`"
        when :test then "`1 MT = 1M TESTS = #{base_per_mvest} TEST = #{base_per_debt}`"
        end
      end
      
      # Instead of all MVESTS for the entire chain, we are looking at specific
      # account names or a search pattern thereof.
      
      case chain
      when :steem
        vests = 0
        delegated_vests = 0
        received_vests = 0
        account = nil
        wildcards = false
        
        account_names.each do |a|
          if a =~ /.*\*$/
            wildcards = true
            lower_bound_name = a.split('*').first
            response = api(chain).lookup_accounts(a, 1000)
            result = response.result
            
            if result.any?
              account_names -= [a]
              account_names += [lower_bound_name]
              account_names += result.map { |name| name if name =~ /#{lower_bound_name}.*/ }.compact
            end
          end
        end
        
        account_names = account_names.map(&:downcase).uniq
        accounts = SteemData::Account.where(:name.in => account_names)
        account = accounts.last
        
        if accounts.count == account_names.size
          vests = accounts.sum('vesting_shares.amount')
          delegated_vests = accounts.sum('delegated_vesting_shares.amount')
          received_vests = accounts.sum('received_vesting_shares.amount')
        elsif !wildcards
          valid_names = accounts.distinct(:name)
          unknown_names = account_names - valid_names
          return unknown_account(unknown_names.first)
        end
        
        if accounts.count == 1 && vests == 0.0
          # Falling back to RPC because balance is out of date and we only want
          # a single account.
          response = api(:steem).get_accounts([account.name])
          account = response.result.first
          vests = account.vesting_shares.split(' ').first.to_f
          delegated_vests = account.delegated_vesting_shares.split(' ').first.to_f
          received_vests = account.received_vesting_shares.split(' ').first.to_f
        end
        
        mvests = vests / 1000000
        delegated_vests = (received_vests - delegated_vests) / 1000000
        steem = base_per_mvest * mvests
        sbd = base_per_debt * mvests
        pol_sbd = base_per_mvest * mvests * pol_usdt_steem
        
        mvests = number_with_precision(mvests, precision: 3, delimiter: ',', separator: '.')
        delegated_sign = delegated_vests >= 0.0 ? '+' : '-'
        delegated_vests = number_with_precision(delegated_vests.abs, precision: 3, delimiter: ',', separator: '.')
        steem = number_with_precision(steem, precision: 3, delimiter: ',', separator: '.')
        sbd = number_to_currency(sbd, precision: 3)
        pol_sbd = number_to_currency(pol_sbd, precision: 3)
        
        if accounts.size == 1
          balance = ["#{mvests} MVESTS = #{steem} STEEM = #{sbd} = #{pol_sbd} on Poloniex"]
          unless delegated_vests == '0.000'
            balance << "(#{delegated_sign}#{delegated_vests} MVESTS delegated)"
          end
          
          "**#{account.name}:** `#{balance.join(' ')}`"
        else
          balance = ["#{mvests} MVESTS = #{steem} STEEM = #{sbd} = #{pol_sbd} on Poloniex"]
          unless delegated_vests == '0.000'
            balance << "(#{delegated_sign}#{delegated_vests} MVESTS delegated)"
          end
          
          "**#{pluralize(accounts.count, 'account')}:** `#{balance.join(' ')}`"
        end
      when :golos
        response = api(:golos).get_accounts(account_names)
        account = response.result.first
        gests = account.vesting_shares.split(' ').first.to_f
        
        mgests = gests / 1000000
        golos = base_per_mvest * mgests
        gbg = base_per_debt * mgests
        _btc_gld, usdt_gld_per_milli = gold_price
        usd = gbg * usdt_gld_per_milli
        
        mgests = number_with_precision(mgests, precision: 3, delimiter: ',', separator: '.')
        golos = number_with_precision(golos, precision: 3, delimiter: ',', separator: '.')
        gbg = number_with_precision(gbg, precision: 3, delimiter: ',', separator: '.')
        usd = number_to_currency(usd, precision: 3)
        
        "**#{account.name}:** `#{mgests} MGESTS = #{golos} GOLOS = #{gbg} GBG = #{usd}`"
      when :test then "Query not supported.  No Mongo for Testnet."
      end
    end
    
    def rewardpool(chain = :steem)
      pol_usdt_steem, _pol_usdt_sbd, btx_usdt_golos, _btx_usdt_gbg = market_data
      base_per_mvest, base_per_debt = price_feed(chain)
      
      case chain
      when :steem
        response = api(chain).get_reward_fund 'post'
        reward_fund = response.result
        total = reward_fund.reward_balance
        total = total.split(' ').first.to_f
        total_usd = (total / base_per_mvest) * base_per_debt
        pol_total_usd = total * pol_usdt_steem
        
        total = number_with_precision(total, precision: 0, delimiter: ',', separator: '.')
        total_usd = number_to_currency(total_usd, precision: 0)
        pol_total_usd = number_to_currency(pol_total_usd, precision: 0)
        
        "Total Reward Fund: `#{total} STEEM (Worth: #{total_usd} internally; #{pol_total_usd} on Poloniex)`"
      when :golos
        response = api(chain).get_dynamic_global_properties
        properties = response.result
        total = properties.total_reward_fund_steem
        total = total.split(' ').first.to_f
        total_gbg = (total / base_per_mvest) * base_per_debt
        btx_total_usd = total * btx_usdt_golos
        
        total = number_with_precision(total, precision: 0, delimiter: ',', separator: '.')
        total_gbg = number_with_precision(total_gbg, precision: 0, delimiter: ',', separator: '.')
        btx_total_usd = number_to_currency(btx_total_usd, precision: 0)
      
        "Total Reward Fund: `#{total} GOLOS (Worth: #{total_gbg} GBG internally; #{btx_total_usd} on Bittrex)`"
      when :test
        "Total Reward Fund: `#{('%.3f' % total)} TEST (Worth: #{('%.3f' % total_usd)} TBD internally)`"
      end
    end
    
    def ticker
      pol_usdt_steem, pol_usdt_sbd, btx_usdt_golos, btx_usdt_gbg = market_data
      
      pol_usdt_steem = number_to_currency(pol_usdt_steem, precision: 4)
      pol_usdt_sbd = number_to_currency(pol_usdt_sbd, precision: 4)
      btx_usdt_golos = number_to_currency(btx_usdt_golos, precision: 4)
      btx_usdt_gbg = number_to_currency(btx_usdt_gbg, precision: 4)

      ticker = []
      ticker << "`Poloniex: USD/STEEM: #{pol_usdt_steem}; USD/SBD: #{pol_usdt_sbd}`"
      ticker << "`Bittrex: USD/GOLOS: #{btx_usdt_golos}; USD/GBG: #{btx_usdt_gbg}`"
      ticker.join("\n")
    end
    
    def promoted(chain = :steem, period = :today)
      return "Query not supported.  No Mongo for #{chain.to_s.capitalize}." unless chain == :steem
      
      promoted = SteemData::AccountOperation.type('transfer').where(account: 'null', to: 'null', 'amount.asset' => 'SBD').send(period)
      count_promoted = promoted.count
      sum_promoted = promoted.sum('amount.amount')
      
      base_per_mvest, base_per_debt = price_feed(chain)
      response = api(chain).get_reward_fund 'post'
      reward_fund = response.result
      total = reward_fund.reward_balance
      total = total.split(' ').first.to_f
      
      total_usd = (total / base_per_mvest) * base_per_debt
      ratio = (sum_promoted / total_usd) * 100
      
      sum_promoted = number_to_currency(sum_promoted, precision: 3)
      ratio = number_to_percentage(ratio, precision: 3)
      
      "#{pluralize(count_promoted, 'post')} promoted #{period} totalling #{sum_promoted} (#{ratio} the size of reward pool)."
    end
    
    def supply(chain)
      base_per_mvest, base_per_debt = price_feed(chain)

      response = api(chain).get_dynamic_global_properties
      properties = response.result
      current_supply = properties.current_supply.split(' ').first.to_f
      current_debt_supply = properties.current_sbd_supply.split(' ').first.to_f
      total_vesting_fund_steem = properties.total_vesting_fund_steem.split(' ').first.to_f
      
      total_base = (current_supply / base_per_mvest) * base_per_debt
      ratio = (current_debt_supply / total_base) * 100
      
      supply = []
      case chain
      when :steem
        response = api(chain).get_reward_fund 'post'
        reward_fund = response.result
        reward_balance = reward_fund.reward_balance
        reward_balance = reward_balance.split(' ').first.to_f
        
        liquid_supply = current_supply - reward_balance - total_vesting_fund_steem
        ratio_liquid = (liquid_supply / current_supply) * 100

        current_supply = number_with_precision(current_supply, precision: 0, delimiter: ',', separator: '.')
        ratio = number_to_percentage(ratio, precision: 3)
        total_base = number_to_currency(total_base, precision: 0)
        current_debt_supply = number_to_currency(current_debt_supply, precision: 0)
        liquid_supply = number_with_precision(liquid_supply, precision: 0, delimiter: ',', separator: '.')
        ratio_liquid = number_to_percentage(ratio_liquid, precision: 3)
      
        supply << ["#{current_supply} STEEM (Worth #{total_base} SBD)"]
        supply << ["#{current_debt_supply} SBD (#{ratio} of supply)"]
        supply << ["#{liquid_supply} Liquid STEEM (#{ratio_liquid} of supply)"]
      when :golos
        properties = response.result
        reward_balance = properties.total_reward_fund_steem
        reward_balance = reward_balance.split(' ').first.to_f
        
        liquid_supply = current_supply - reward_balance - total_vesting_fund_steem
        ratio_liquid = (liquid_supply / current_supply) * 100
        
        current_supply = number_with_precision(current_supply, precision: 0, delimiter: ',', separator: '.')
        ratio = number_to_percentage(ratio, precision: 3)
        total_base = number_with_precision(total_base, precision: 0, delimiter: ',', separator: '.')
        current_debt_supply = number_with_precision(current_debt_supply, precision: 0, delimiter: ',', separator: '.')
        liquid_supply = number_with_precision(liquid_supply, precision: 0, delimiter: ',', separator: '.')
        ratio_liquid = number_to_percentage(ratio_liquid, precision: 3)
        
        supply << ["#{current_supply} GOLOS (Worth #{total_base} GBG)"]
        supply << ["#{current_debt_supply} GBG (#{ratio} of supply)"]
        supply << ["#{liquid_supply} Liquid GOLOS (#{ratio_liquid} of supply)"]
      when :test
        properties = response.result
        reward_balance = properties.total_reward_fund_steem
        reward_balance = reward_balance.split(' ').first.to_f
        
        liquid_supply = current_supply - reward_balance - total_vesting_fund_steem
        ratio_liquid = (liquid_supply / current_supply) * 100
        
        current_supply = number_with_precision(current_supply, precision: 0, delimiter: ',', separator: '.')
        ratio = number_to_percentage(ratio, precision: 3)
        total_base = number_with_precision(total_base, precision: 0, delimiter: ',', separator: '.')
        current_debt_supply = number_with_precision(current_debt_supply, precision: 0, delimiter: ',', separator: '.')
        liquid_supply = number_with_precision(liquid_supply, precision: 0, delimiter: ',', separator: '.')
        ratio_liquid = number_to_percentage(ratio_liquid, precision: 3)
        
        supply << ["#{current_supply} CORE (Worth #{total_base} TBD)"]
        supply << ["#{current_debt_supply} TBD (#{ratio} of supply)"]
        supply << ["#{liquid_supply} Liquid CORE (#{ratio_liquid} of supply)"]
      end
      
      "Supply: `" + supply.join('; ') + "`"
    end
    
    def mvests_sum(options = {})
      chain = options[:chain] || :steem
      account_names = options[:account_names]
      case chain
      when :steem then SteemData::Account.where(:name.in => account_names).sum('vesting_shares.amount')
      when :golos then "Query not supported.  No Mongo for Golos."
      when :test then "Query not supported.  No Mongo for Testnet."
      end
    end
    
    def debt_exchange_rate(chain = :steem, limit = 19)
      chain = chain.to_sym
      response = api(chain).get_witnesses_by_vote('', limit)
      witnesses = response.result
      rates = witnesses.map(&:sbd_exchange_rate)
      
      symbol = case chain
      when :steem then 'SBD'
      when :golos then 'GBG'
      end
      
      ratio = rates.map do |r|
        b = r.base.split(' ').first.to_f
        q = r.quote.split(' ').first.to_f
        
        b / q unless q == 0.0
      end.compact
      
      price = ratio.sum / ratio.size
      price = number_with_precision(price, precision: 3, delimiter: ',', separator: '.')
      
      "#{price} #{symbol}"
    end
    
    def apr(chain = :steem, limit = 19)
      chain = chain.to_sym
      response = api(chain).get_witnesses_by_vote('', limit)
      witnesses = response.result
      rates = witnesses.map(&:props).map { |p| p['sbd_interest_rate'] }
      
      rate = rates.sum / rates.size
      rate = rate / 100.0
      number_to_percentage(rate, precision: 3)
    end
    
    def effective_apr(chain = :steem)
      chain = chain.to_sym
      response = api(chain).get_dynamic_global_properties
      properties = response.result
      rate = properties.sbd_interest_rate
      
      rate = rate / 100.0
      number_to_percentage(rate, precision: 3)
    end
    
    def effective_price(chain = :steem)
      chain = chain.to_sym
      response = api(chain).get_feed_history
      feed_history = response.result
      current_median_history = feed_history.current_median_history
      
      b = current_median_history.base.split(' ').first.to_f
      q = current_median_history.quote.split(' ').first.to_f
      
      symbol = case chain
      when :steem then 'SBD'
      when :golos then 'GBG'
      end
      
      price = b / q
      price = number_with_precision(price, precision: 3, delimiter: ',', separator: '.')
      
      "#{price} #{symbol}"
    end
  end
end
