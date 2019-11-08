module Cosgrove
  module Market
    include Support
    include ActionView::Helpers::NumberHelper
    
    def base_per_mvest(chain = :steem)
      api(chain).get_dynamic_global_properties do |properties|
        total_vesting_fund_steem = properties.total_vesting_fund_steem.to_f
        total_vesting_shares_mvest = properties.total_vesting_shares.to_f / 1e6
      
        total_vesting_fund_steem / total_vesting_shares_mvest
      end
    end
    
    def price_feed(chain = :steem)
      api(chain).get_feed_history do |feed_history|
        current_median_history = feed_history.current_median_history
        base = current_median_history.base
        base = base.split(' ').first.to_f
        quote = current_median_history.quote
        quote = quote.split(' ').first.to_f
        
        base_per_debt = (base / quote) * base_per_mvest(chain)
        
        [base_per_mvest, base_per_debt]
      end
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
      pol_usdt_btc = JSON[open("https://poloniex.com/public?command=returnOrderBook&currencyPair=USDT_BTC&depth=10").read]
      
      pol_btc_steem = pol_btc_steem['asks'].first.first.to_f
      pol_usdt_btc = pol_usdt_btc['asks'].first.first.to_f
      
      pol_usdt_steem = pol_usdt_btc * pol_btc_steem
      
      btx_usdt_btc = JSON[open("https://bittrex.com/api/v1.1/public/getmarketsummary?market=usdt-btc").read]
      
      btx_usdt_btc = btx_usdt_btc['result'].first['Ask'].to_f
      
      btx_btc_steem = JSON[open("https://bittrex.com/api/v1.1/public/getmarketsummary?market=btc-steem").read]
      btx_btc_sbd = JSON[open("https://bittrex.com/api/v1.1/public/getmarketsummary?market=btc-sbd").read]
      
      btx_btc_steem = btx_btc_steem['result'].first['Ask'].to_f
      btx_btc_sbd = btx_btc_sbd['result'].first['Ask'].to_f
      
      btx_usdt_sbd = btx_usdt_btc * btx_btc_sbd
      btx_usdt_steem = btx_usdt_btc * btx_btc_steem
      
      [pol_usdt_steem, btx_usdt_steem, btx_usdt_sbd]
    end
    
    def btx_market_data
      btx_usdt_btc = JSON[open("https://bittrex.com/api/v1.1/public/getmarketsummary?market=usdt-btc").read]
      
      btx_usdt_btc = btx_usdt_btc['result'].first['Ask'].to_f
      
      btx_btc_steem = JSON[open("https://bittrex.com/api/v1.1/public/getmarketsummary?market=btc-steem").read]
      btx_btc_sbd = JSON[open("https://bittrex.com/api/v1.1/public/getmarketsummary?market=btc-sbd").read]
      
      btx_btc_steem = btx_btc_steem['result'].first['Ask'].to_f
      btx_btc_sbd = btx_btc_sbd['result'].first['Ask'].to_f
      
      btx_usdt_sbd = btx_usdt_btc * btx_btc_sbd
      btx_usdt_steem = btx_usdt_btc * btx_btc_steem
      
      {usdt_steem: btx_usdt_steem, usdt_sbd: btx_usdt_sbd}
    end
    
    def mvests(chain = :steem, account_names = [])
      _btx_market_data = btx_market_data
      btx_usdt_steem, btx_usdt_sbd = _btx_market_data[:usdt_steem], _btx_market_data[:usdt_sbd]
      base_per_mvest, base_per_debt = price_feed(chain)
      
      if account_names.none?
        btx_base_per_dept_as_usdt = base_per_mvest * btx_usdt_steem
        btx_base_per_dept_as_usdt = number_to_currency(btx_base_per_dept_as_usdt, precision: 3)
        
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
        when :steem then "`1 MV = 1M VESTS = #{base_per_mvest} STEEM = #{base_per_debt} = #{btx_base_per_dept_as_usdt} on Bittrex`"
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
            api(chain).lookup_accounts(a, 1000) do |names, error|
              if names.any?
                account_names -= [a]
                account_names += [lower_bound_name]
                account_names += names.map { |name| name if name =~ /#{lower_bound_name}.*/ }.compact
              end
            end
          end
        end
        
        account_names = account_names.map(&:downcase).uniq
        accounts = SteemApi::Account.where(name: account_names)
        account = accounts.limit(1).first
        
        if accounts.count == account_names.size
          vests = accounts.pluck(:vesting_shares).map(&:to_f).sum
          delegated_vests = accounts.pluck(:delegated_vesting_shares).map(&:to_f).sum
          received_vests = accounts.pluck(:received_vesting_shares).map(&:to_f).sum
        elsif !wildcards
          valid_names = accounts.distinct(:name)
          unknown_names = account_names - valid_names
          return unknown_account(unknown_names.first)
        end
        
        if accounts.count == 1 && vests == 0.0
          # Falling back to RPC because balance is out of date and we only want
          # a single account.
          api(:steem).get_accounts([account.name]) do |accounts|
            account = accounts.first
            vests = account.vesting_shares.split(' ').first.to_f
            delegated_vests = account.delegated_vesting_shares.split(' ').first.to_f
            received_vests = account.received_vesting_shares.split(' ').first.to_f
          end
        end
        
        mvests = vests / 1000000
        delegated_vests = (received_vests - delegated_vests) / 1000000
        steem = base_per_mvest * mvests
        sbd = base_per_debt * mvests
        btx_sbd = base_per_mvest * mvests * btx_usdt_steem
        
        mvests = number_with_precision(mvests, precision: 3, delimiter: ',', separator: '.')
        delegated_sign = delegated_vests >= 0.0 ? '+' : '-'
        delegated_vests = number_with_precision(delegated_vests.abs, precision: 3, delimiter: ',', separator: '.')
        steem = number_with_precision(steem, precision: 3, delimiter: ',', separator: '.')
        sbd = number_to_currency(sbd, precision: 3)
        btx_sbd = number_to_currency(btx_sbd, precision: 3)
        
        if accounts.size == 1
          balance = ["#{mvests} MVESTS = #{steem} STEEM = #{sbd} = #{btx_sbd} on Bittrex"]
          unless delegated_vests == '0.000'
            balance << "(#{delegated_sign}#{delegated_vests} MVESTS delegated)"
          end
          
          "**#{account.name}:** `#{balance.join(' ')}`"
        else
          balance = ["#{mvests} MVESTS = #{steem} STEEM = #{sbd} = #{btx_sbd} on Bittrex"]
          unless delegated_vests == '0.000'
            balance << "(#{delegated_sign}#{delegated_vests} MVESTS delegated)"
          end
          
          "**#{pluralize(accounts.count, 'account')}:** `#{balance.join(' ')}`"
        end
      when :golos
        account = nil
        gests = nil
        
        api(:golos).get_accounts(account_names) do |accounts, error|
          account = accounts.first
          gests = account.vesting_shares.split(' ').first.to_f
        end
        
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
      when :test then "Query not supported.  No database for Testnet."
      end
    end
    
    def rewardpool(chain = :steem)
      _btx_market_data = btx_market_data
      btx_usdt_steem, btx_usdt_sbd = _btx_market_data[:usdt_steem], _btx_market_data[:usdt_sbd]
      base_per_mvest, base_per_debt = price_feed(chain)
      
      case chain
      when :steem
        total = api(chain).get_reward_fund('post') do |reward_fund|
          reward_fund.reward_balance.split(' ').first.to_f
        end
        
        total_usd = (total / base_per_mvest) * base_per_debt
        btx_total_usd = total * btx_usdt_steem
        
        total = number_with_precision(total, precision: 0, delimiter: ',', separator: '.')
        total_usd = number_to_currency(total_usd, precision: 0)
        btx_total_usd = number_to_currency(btx_total_usd, precision: 0)
        
        "Total Reward Fund: `#{total} STEEM (Worth: #{total_usd} internally; #{btx_total_usd} on Bittrex)`"
      when :golos
        total = api(chain).get_dynamic_global_properties do |properties|
          properties.total_reward_fund_steem.split(' ').first.to_f
        end
        
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
    
    def ticker(event = nil)
      ticker = []
      message = nil
      
      event.channel.start_typing if !!event
      
      begin
        _btx_market_data = btx_market_data
        btx_usdt_steem, btx_usdt_sbd = _btx_market_data[:usdt_steem], _btx_market_data[:usdt_sbd]

        btx_usdt_steem = number_to_currency(btx_usdt_steem, precision: 4)
        btx_usdt_sbd = number_to_currency(btx_usdt_sbd, precision: 4)

        ticker << "`bittrex.com: USD/STEEM: #{btx_usdt_steem}; USD/SBD: #{btx_usdt_sbd}`"
      rescue => e
        puts e
      end
      
      if !!event
        message = event.respond ticker.join("\n")
        event.channel.start_typing
      end
      
      begin
        bin_steem_btc = JSON[open('https://api.binance.com/api/v1/ticker/price?symbol=STEEMBTC').read].fetch('price').to_f
        bin_btc_usdt = JSON[open('https://api.binance.com/api/v1/ticker/price?symbol=BTCUSDT').read].fetch('price').to_f
        bin_usdt_steem = bin_btc_usdt * bin_steem_btc
        bin_usdt_steem = number_to_currency(bin_usdt_steem, precision: 4)
        
        ticker << "`binance.com: USD/STEEM: #{bin_usdt_steem}`"
      rescue => e
        puts e
      end
      
      message.edit ticker.join("\n") if !!message
      event.channel.start_typing if !!event
      
      begin
        upb_btc_steem = JSON[open('https://api.upbit.com/v1/trades/ticks?market=BTC-STEEM').read][0].fetch('trade_price').to_f
        upb_btc_sbd = JSON[open('https://api.upbit.com/v1/trades/ticks?market=BTC-SBD').read][0].fetch('trade_price').to_f
        upb_usdt_btc = JSON[open('https://api.upbit.com/v1/trades/ticks?market=USDT-BTC').read][0].fetch('trade_price').to_f
        upb_usdt_steem = upb_usdt_btc * upb_btc_steem
        upb_usdt_sbd = upb_usdt_btc * upb_btc_sbd
        upb_usdt_steem = number_to_currency(upb_usdt_steem, precision: 4)
        upb_usdt_sbd = number_to_currency(upb_usdt_sbd, precision: 4)
        
        ticker << "`upbit.com: USD/STEEM: #{upb_usdt_steem}; USD/SBD: #{upb_usdt_sbd}`"
      rescue => e
        puts e
      end
      
      message.edit ticker.join("\n") if !!message
      event.channel.start_typing if !!event
      
      begin
        post_promoter_feed = JSON[open('https://postpromoter.net/api/prices').read]
        pp_usd_steem = post_promoter_feed.fetch('steem_price').to_f
        pp_usd_sbd = post_promoter_feed.fetch('sbd_price').to_f
        pp_usd_steem = number_to_currency(pp_usd_steem, precision: 4)
        pp_usd_sbd = number_to_currency(pp_usd_sbd, precision: 4)
        
        ticker << "`postpromoter.net: USD/STEEM: #{pp_usd_steem}; USD/SBD: #{pp_usd_sbd}`"
      rescue => e
        puts e
      end
      
      message.edit ticker.join("\n") if !!message
      event.channel.start_typing if !!event
      
      begin
        cg_steem = JSON[open('https://api.coingecko.com/api/v3/coins/steem').read]
        cg_sbd = JSON[open('https://api.coingecko.com/api/v3/coins/steem-dollars').read]
        cg_usd_steem = cg_steem.fetch('market_data').fetch('current_price').fetch('usd').to_f
        cg_usd_sbd = cg_sbd.fetch('market_data').fetch('current_price').fetch('usd').to_f
        
        ticker << "`coingecko.com: USD/STEEM: $#{cg_usd_steem}; USD/SBD: $#{cg_usd_sbd}`"
      rescue => e
        puts e
      end
      
      if !!message
        message.edit ticker.join("\n")
        
        return nil
      end
        
      ticker.join("\n")
    end
    
    def promoted(chain = :steem, period = :today)
      return "Query not supported.  No database for #{chain.to_s.capitalize}." unless chain == :steem
      
      promoted = SteemApi::Tx::Transfer.where(to: 'null', amount_symbol: 'SBD').send(period)
      count_promoted = promoted.count
      sum_promoted = promoted.sum(:amount)
      
      base_per_mvest, base_per_debt = price_feed(chain)
      total = api(chain).get_reward_fund('post') do |reward_fund|
        reward_fund.reward_balance.split(' ').first.to_f
      end
      
      total_usd = (total / base_per_mvest) * base_per_debt
      ratio = (sum_promoted / total_usd) * 100
      
      sum_promoted = number_to_currency(sum_promoted, precision: 3)
      ratio = number_to_percentage(ratio, precision: 3)
      
      "#{pluralize(count_promoted, 'post')} promoted #{period} totalling #{sum_promoted} (#{ratio} the size of reward pool)."
    end
    
    def supply(chain)
      base_per_mvest, base_per_debt = price_feed(chain)
      properties = api(chain).get_dynamic_global_properties do |_properties, error|
        _properties
      end
      
      current_supply = properties.current_supply.split(' ').first.to_f
      current_debt_supply = properties.current_sbd_supply.split(' ').first.to_f
      total_vesting_fund_steem = properties.total_vesting_fund_steem.split(' ').first.to_f
      virtual_supply = properties.virtual_supply.split(' ').first.to_f
      debt_steem = virtual_supply - current_supply
      total_base = (current_supply / base_per_mvest) * base_per_debt
      ratio = (debt_steem / virtual_supply) * 100
      
      supply = []
      case chain
      when :steem
        reward_balance = api(chain).get_reward_fund('post') do |reward_fund|
          reward_fund.reward_balance.split(' ').first.to_f
        end
        
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
      when :steem then SteemApi::Account.where(name: account_names).sum("TRY_PARSE(REPLACE(vesting_shares, ' VESTS', '') AS float)")
      when :golos then "Query not supported.  No database for Golos."
      when :test then "Query not supported.  No database for Testnet."
      end
    end
    
    def debt_exchange_rate(chain = :steem, limit = 19)
      chain = chain.to_sym
      rates = api(chain).get_witnesses_by_vote('', limit) do |witnesses|
        witnesses.map(&:sbd_exchange_rate)
      end
      
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
      rates = api(chain).get_witnesses_by_vote('', limit) do |witnesses|
        witnesses.map(&:props).map { |p| p['sbd_interest_rate'] }
      end
      
      rate = rates.sum / rates.size
      rate = rate / 100.0
      number_to_percentage(rate, precision: 3)
    end
    
    def effective_apr(chain = :steem)
      chain = chain.to_sym
      rate = api(chain).get_dynamic_global_properties do |properties|
        properties.sbd_interest_rate
      end
      
      rate = rate / 100.0
      number_to_percentage(rate, precision: 3)
    end
    
    def effective_price(chain = :steem)
      chain = chain.to_sym
      current_median_history = api(chain).get_feed_history do |feed_history|
        feed_history.current_median_history
      end
      
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
