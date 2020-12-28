module Cosgrove
  module Market
    include Support
    include Utils
    include ActionView::Helpers::NumberHelper
    
    def base_per_mvest(chain = :hive)
      api(chain).get_dynamic_global_properties do |properties|
        case chain
        when :steem
          total_vesting_fund_base = properties.total_vesting_fund_steem.to_f
          total_vesting_shares_mvest = properties.total_vesting_shares.to_f / 1e6
        when :hive
          total_vesting_fund_base = properties.total_vesting_fund_hive.to_f
          total_vesting_shares_mvest = properties.total_vesting_shares.to_f / 1e6
        end
      
        total_vesting_fund_base / total_vesting_shares_mvest
      end
    end
    
    def price_feed(chain = :hive)
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
      
      btx_usdt_btc = btx_usdt_btc['result'].first['Last'].to_f
      
      btx_btc_steem = JSON[open("https://bittrex.com/api/v1.1/public/getmarketsummary?market=btc-steem").read]
      btx_btc_sbd = JSON[open("https://bittrex.com/api/v1.1/public/getmarketsummary?market=btc-sbd").read]
      
      btx_btc_steem = btx_btc_steem['result'].first['Last'].to_f
      btx_btc_sbd = btx_btc_sbd['result'].first['Last'].to_f
      
      btx_usdt_sbd = btx_usdt_btc * btx_btc_sbd
      btx_usdt_steem = btx_usdt_btc * btx_btc_steem
      
      btx_btc_hive = JSON[open("https://bittrex.com/api/v1.1/public/getmarketsummary?market=btc-hive").read]
      btx_usdt_hive = JSON[open("https://bittrex.com/api/v1.1/public/getmarketsummary?market=usdt-hive").read]
      btx_btc_hbd = JSON[open("https://bittrex.com/api/v1.1/public/getmarketsummary?market=btc-hbd").read]
      
      btx_btc_hive = btx_btc_hive['result'].first['Last'].to_f
      btx_usdt_hive = btx_usdt_hive['result'].first['Last'].to_f
      btx_btc_hbd = btx_btc_hbd['result'].first['Last'].to_f
      
      btx_usdt_hbd = btx_usdt_btc * btx_btc_hbd
      
      {
        usdt_steem: btx_usdt_steem,
        usdt_sbd: btx_usdt_sbd,
        btc_steem: btx_btc_steem,
        btc_sbd: btx_btc_sbd,
        usdt_hive: btx_usdt_hive,
        usdt_hbd: btx_usdt_hbd,
        btc_hive: btx_btc_hive,
        btc_hbd: btx_btc_hbd
      }
    end
    
    def mvests(chain = :hive, account_names = [])
      chain = chain.to_s.downcase.to_sym
      _btx_market_data = btx_market_data
      btx_usdt_steem, btx_usdt_sbd = _btx_market_data[:usdt_steem], _btx_market_data[:usdt_sbd]
      btx_usdt_hive, btx_usdt_hbd = _btx_market_data[:usdt_hive], _btx_market_data[:usdt_hbd]
      base_per_mvest, base_per_debt = price_feed(chain)
      
      if account_names.none?
        btx_base_per_dept_as_usdt = case chain
        when :steem then base_per_mvest * btx_usdt_steem
        when :hive then base_per_mvest * btx_usdt_hive
        end
        btx_base_per_dept_as_usdt = number_to_currency(btx_base_per_dept_as_usdt, precision: 3)
        
        base_per_mvest = number_with_precision(base_per_mvest, precision: 3, delimiter: ',', separator: '.')
        
        base_per_debt = if chain == :steem || chain == :hive
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
        when :hive then "`1 MV = 1M VESTS = #{base_per_mvest} HIVE = #{base_per_debt} = #{btx_base_per_dept_as_usdt} on Bittrex`"
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
        # accounts = SteemApi::Account.where(name: account_names)
        # account = accounts.limit(1).first
        
        # if accounts.count == account_names.size
        #   vests = accounts.pluck(:vesting_shares).map(&:to_f).sum
        #   delegated_vests = accounts.pluck(:delegated_vesting_shares).map(&:to_f).sum
        #   received_vests = accounts.pluck(:received_vesting_shares).map(&:to_f).sum
        # elsif !wildcards
        #   valid_names = accounts.distinct(:name)
        #   unknown_names = account_names - valid_names
        #   return unknown_account(unknown_names.first)
        # end
        
        # if accounts.count == 1 && vests == 0.0
        #   # Falling back to RPC because balance is out of date and we only want
        #   # a single account.
        #   api(:steem).get_accounts([account.name]) do |accounts|
        #     account = accounts.first
        #     vests = account.vesting_shares.split(' ').first.to_f
        #     delegated_vests = account.delegated_vesting_shares.split(' ').first.to_f
        #     received_vests = account.received_vesting_shares.split(' ').first.to_f
        #   end
        # end
        
        # mvests = vests / 1000000
        # delegated_vests = (received_vests - delegated_vests) / 1000000
        # steem = base_per_mvest * mvests
        # sbd = base_per_debt * mvests
        # btx_sbd = base_per_mvest * mvests * btx_usdt_steem
        # 
        # mvests = number_with_precision(mvests, precision: 3, delimiter: ',', separator: '.')
        # delegated_sign = delegated_vests >= 0.0 ? '+' : '-'
        # delegated_vests = number_with_precision(delegated_vests.abs, precision: 3, delimiter: ',', separator: '.')
        # steem = number_with_precision(steem, precision: 3, delimiter: ',', separator: '.')
        # sbd = number_to_currency(sbd, precision: 3)
        # btx_sbd = number_to_currency(btx_sbd, precision: 3)
        # 
        # if accounts.size == 1
        #   balance = ["#{mvests} MVESTS = #{steem} STEEM = #{sbd} = #{btx_sbd} on Bittrex"]
        #   unless delegated_vests == '0.000'
        #     balance << "(#{delegated_sign}#{delegated_vests} MVESTS delegated)"
        #   end
        # 
        #   "**#{account.name}:** `#{balance.join(' ')}`"
        # else
        #   balance = ["#{mvests} MVESTS = #{steem} STEEM = #{sbd} = #{btx_sbd} on Bittrex"]
        #   unless delegated_vests == '0.000'
        #     balance << "(#{delegated_sign}#{delegated_vests} MVESTS delegated)"
        #   end
        # 
        #   "**#{pluralize(accounts.count, 'account')}:** `#{balance.join(' ')}`"
        # end
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
      when :hive
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
        accounts = HiveSQL::Account.where(name: account_names)
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
          api(chain).get_accounts([account.name]) do |accounts|
            account = accounts.first
            vests = account.vesting_shares.split(' ').first.to_f
            delegated_vests = account.delegated_vesting_shares.split(' ').first.to_f
            received_vests = account.received_vesting_shares.split(' ').first.to_f
          end
        end
        
        mvests = vests / 1000000
        delegated_vests = (received_vests - delegated_vests) / 1000000
        hive = base_per_mvest * mvests
        hbd = base_per_debt * mvests
        btx_hbd = base_per_mvest * mvests * btx_usdt_hive
        
        mvests = number_with_precision(mvests, precision: 3, delimiter: ',', separator: '.')
        delegated_sign = delegated_vests >= 0.0 ? '+' : '-'
        delegated_vests = number_with_precision(delegated_vests.abs, precision: 3, delimiter: ',', separator: '.')
        hive = number_with_precision(hive, precision: 3, delimiter: ',', separator: '.')
        hbd = number_to_currency(hbd, precision: 3)
        btx_hbd = number_to_currency(btx_hbd, precision: 3)
        
        if accounts.size == 1
          balance = ["#{mvests} MVESTS = #{hive} HIVE = #{hbd} = #{btx_hbd} on Bittrex"]
          unless delegated_vests == '0.000'
            balance << "(#{delegated_sign}#{delegated_vests} MVESTS delegated)"
          end
          
          "**#{account.name}:** `#{balance.join(' ')}`"
        else
          balance = ["#{mvests} MVESTS = #{hive} HIVE = #{hbd} = #{btx_hbd} on Bittrex"]
          unless delegated_vests == '0.000'
            balance << "(#{delegated_sign}#{delegated_vests} MVESTS delegated)"
          end
          
          "**#{pluralize(accounts.count, 'account')}:** `#{balance.join(' ')}`"
        end
      when :test then "Query not supported.  No database for Testnet."
      end
    end
    
    def rewardpool(chain = :hive)
      chain = chain.to_s.downcase.to_sym
      _btx_market_data = btx_market_data
      btx_usdt_steem, btx_usdt_sbd = _btx_market_data[:usdt_steem], _btx_market_data[:usdt_sbd]
      btx_usdt_hive, btx_usdt_hbd = _btx_market_data[:usdt_hive], _btx_market_data[:usdt_hbd]
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
      when :hive
        total = api(chain).get_reward_fund('post') do |reward_fund|
          reward_fund.reward_balance.split(' ').first.to_f
        end
        
        total_usd = (total / base_per_mvest) * base_per_debt
        btx_total_usd = total * btx_usdt_hive
        
        total = number_with_precision(total, precision: 0, delimiter: ',', separator: '.')
        total_usd = number_to_currency(total_usd, precision: 0)
        btx_total_usd = number_to_currency(btx_total_usd, precision: 0)
        
        "Total Reward Fund: `#{total} HIVE (Worth: #{total_usd} internally; #{btx_total_usd} on Bittrex)`"
      end
    end
    
    def render_ticker(message, event, ticker = {}, chain = :hive)
      chain ||= :hive
      ticker ||= {}
      chain = chain.to_s.downcase.to_sym
      return if ticker.size < 1
      
      start_typing event
      
      ticker_text = case chain
      when :steem
        "```markdown\n" +
        "|                   |  USD/STEEM  |   USD/SBD   |  BTC/STEEM  |   BTC/SBD   |\n" +
        "|-------------------|-------------|-------------|-------------|-------------|\n"
      when :hive
        "```markdown\n" +
        "|                   |  USD/HIVE  |   USD/HBD   |  BTC/HIVE  |   BTC/HBD   |\n" +
        "|-------------------|------------|-------------|------------|-------------|\n"
      end
      
      ticker_text += ticker.map do |key, value|
        "| #{key} | #{value} |"
      end.join("\n")
      
      ticker_text += "\n```\n"
      
      if message.nil? && !!event
        message = event.respond ticker_text
      elsif !!message
        message.edit ticker_text
      end
      
      message || ticker_text
    end
    
    def ticker(event = nil, chain = :hive)
      chain = chain.to_s.downcase.to_sym
      message = nil
      threads = []
      
      case chain
      when :steem
        key_bittrex =      'bittrex.com      '
        key_binance =      'binance.com      '
        key_huobi =        'huobi.pro        '
        key_upbit =        'upbit.com        '
        # key_postpromoter = 'postpromoter.net '
        key_coingecko =    'coingecko.com    '
        key_poloniex =     'poloniex.com     '
        # key_steem_engine = 'steem-engine.com '
        ticker = {
          key_bittrex => nil,
          key_binance => nil,
          key_huobi => nil,
          key_upbit => nil,
          # key_postpromoter => nil,
          key_coingecko => nil,
          key_poloniex => nil,
          # key_steem_engine => nil
        }
        
        threads << Thread.new do
          begin
            _btx_market_data = btx_market_data
            btx_usdt_steem, btx_usdt_sbd = _btx_market_data[:usdt_steem], _btx_market_data[:usdt_sbd]
            btx_btc_steem, btx_btx_sbd = _btx_market_data[:btc_steem], _btx_market_data[:btc_sbd]

            btx_usdt_steem = number_to_currency(btx_usdt_steem, precision: 4).rjust(11)
            btx_usdt_sbd = number_to_currency(btx_usdt_sbd, precision: 4).rjust(11)
            btx_btc_steem = number_to_currency(btx_btc_steem, precision: 8, unit: '').rjust(11)
            btx_btx_sbd = number_to_currency(btx_btx_sbd, precision: 8, unit: '').rjust(11)

            ticker[key_bittrex] = "#{btx_usdt_steem} | #{btx_usdt_sbd} | #{btx_btc_steem} | #{btx_btx_sbd}"
          rescue => e
            puts e
          end
        end
        
        threads << Thread.new do
          begin
            bin_steem_btc = JSON[open('https://api.binance.com/api/v1/ticker/price?symbol=STEEMBTC').read].fetch('price').to_f
            bin_btc_usdt = JSON[open('https://api.binance.com/api/v1/ticker/price?symbol=BTCUSDT').read].fetch('price').to_f
            bin_usdt_steem = bin_btc_usdt * bin_steem_btc
            bin_usdt_steem = number_to_currency(bin_usdt_steem, precision: 4).rjust(11)
            bin_steem_btc = number_to_currency(bin_steem_btc, precision: 8, unit: '').rjust(11)
            
            ticker[key_binance] = "#{bin_usdt_steem} |             | #{bin_steem_btc} |            "
          rescue => e
            puts e
          end
        end
        
        threads << Thread.new do
          begin
            hub_steem_usdt = JSON[open('https://api.huobi.pro/market/detail/merged?symbol=steemusdt').read].fetch('tick').fetch('close').to_f
            hub_steem_btc = JSON[open('https://api.huobi.pro/market/detail/merged?symbol=steembtc').read].fetch('tick').fetch('close').to_f
            hub_steem_usdt = number_to_currency(hub_steem_usdt, precision: 4).rjust(11)
            hub_steem_btc = number_to_currency(hub_steem_btc, precision: 8, unit: '').rjust(11)
            
            ticker[key_huobi] = "#{hub_steem_usdt} |             | #{hub_steem_btc} |            "
          rescue => e
            puts e
          end
        end
        
        threads << Thread.new do
          begin
            upb_btc_steem = JSON[open('https://api.upbit.com/v1/trades/ticks?market=BTC-STEEM').read][0].fetch('trade_price').to_f
            upb_btc_sbd = JSON[open('https://api.upbit.com/v1/trades/ticks?market=BTC-SBD').read][0].fetch('trade_price').to_f
            upb_usdt_btc = JSON[open('https://api.upbit.com/v1/trades/ticks?market=USDT-BTC').read][0].fetch('trade_price').to_f
            upb_usdt_steem = upb_usdt_btc * upb_btc_steem
            upb_usdt_sbd = upb_usdt_btc * upb_btc_sbd
            upb_usdt_steem = number_to_currency(upb_usdt_steem, precision: 4).rjust(11)
            upb_usdt_sbd = number_to_currency(upb_usdt_sbd, precision: 4).rjust(11)
            upb_btc_steem = number_to_currency(upb_btc_steem, precision: 8, unit: '').rjust(11)
            upb_btc_sbd = number_to_currency(upb_btc_sbd, precision: 8, unit: '').rjust(11)
            
            ticker[key_upbit] = "#{upb_usdt_steem} | #{upb_usdt_sbd} | #{upb_btc_steem} | #{upb_btc_sbd}"
          rescue => e
            puts e
          end
        end
        
        # threads << Thread.new do
        #   begin
        #     post_promoter_feed = JSON[open('https://postpromoter.net/api/prices').read]
        #     pp_usd_steem = post_promoter_feed.fetch('steem_price').to_f
        #     pp_usd_sbd = post_promoter_feed.fetch('sbd_price').to_f
        #     pp_usd_steem = number_to_currency(pp_usd_steem, precision: 4).rjust(11)
        #     pp_usd_sbd = number_to_currency(pp_usd_sbd, precision: 4).rjust(11)
        # 
        #     ticker[key_postpromoter] = "#{pp_usd_steem} | #{pp_usd_sbd} |             |            "
        #   rescue => e
        #     puts e
        #   end
        # end
        
        threads << Thread.new do
          begin
            cg_steem = JSON[open('https://api.coingecko.com/api/v3/coins/steem').read]
            cg_sbd = JSON[open('https://api.coingecko.com/api/v3/coins/steem-dollars').read]
            cg_usd_steem = cg_steem.fetch('market_data').fetch('current_price').fetch('usd').to_f
            cg_btc_steem = cg_steem.fetch('market_data').fetch('current_price').fetch('btc').to_f
            cg_usd_sbd = cg_sbd.fetch('market_data').fetch('current_price').fetch('usd').to_f
            cg_btc_sbd = cg_sbd.fetch('market_data').fetch('current_price').fetch('btc').to_f
            cg_usd_steem = number_to_currency(cg_usd_steem, precision: 4).rjust(11)
            cg_usd_sbd = number_to_currency(cg_usd_sbd, precision: 4).rjust(11)
            cg_btc_steem = number_to_currency(cg_btc_steem, precision: 8, unit: '').rjust(11)
            cg_btc_sbd = number_to_currency(cg_btc_sbd, precision: 8, unit: '').rjust(11)
            
            ticker[key_coingecko] = "#{cg_usd_steem} | #{cg_usd_sbd} | #{cg_btc_steem} | #{cg_btc_sbd}"
          rescue => e
            puts e
          end
        end
        
        threads << Thread.new do
          begin
            pol_usdt_btc = JSON[open("https://poloniex.com/public?command=returnOrderBook&currencyPair=USDT_BTC&depth=10").read]
            pol_btc_steem = JSON[open("https://poloniex.com/public?command=returnOrderBook&currencyPair=BTC_STEEM&depth=10").read]
            pol_usdt_btc = pol_usdt_btc['asks'].first.first.to_f
            pol_btc_steem = pol_btc_steem['asks'].first.first.to_f
            pol_usdt_steem = pol_usdt_btc * pol_btc_steem
            pol_usdt_steem = number_to_currency(pol_usdt_steem, precision: 4).rjust(11)
            pol_btc_steem = number_to_currency(pol_btc_steem, precision: 8, unit: '').rjust(11)

            ticker[key_poloniex] = "#{pol_usdt_steem} |             | #{pol_btc_steem} |            "
          rescue => e
            puts e
          end
        end
        
        # threads << Thread.new do
        #   begin
        #     # btc_history_data = steem_engine_contracts(:find, {
        #     #   contract: 'market',
        #     #   table: 'tradesHistory',
        #     #   query: {
        #     #     symbol: 'BTCP'
        #     #   },
        #     #   limit: 1,
        #     #   offset: 0,
        #     #   indexes: [{index: '_id', descending: true}]
        #     # })
        # 
        #     # se_prices = JSON[open('https://postpromoter.net/api/prices').read]
        #     # se_usd_steem = se_prices['steem_price']
        #     # # se_steem_usd = btc_history_data[0]['price'].to_f * se_usd_steem
        #     # # se_btc_steem = se_usd_steem / se_steem_usd
        #     # se_usd_steem = number_to_currency(se_usd_steem, precision: 4).rjust(11)
        #     # # se_btc_steem = number_to_currency(se_btc_steem, precision: 8, unit: '').rjust(11)
        #     # 
        #     # ticker[key_steem_engine] = "#{se_usd_steem} |             |             |            "
        #   rescue => e
        #     puts e
        #   end
        # end
      when :hive
        key_ionomy    =    'ionomy.com       '
        key_bittrex =      'bittrex.com      '
        key_binance =      'binance.com      '
        key_huobi =        'huobi.pro        '
        key_probit    =    'probit.com       '
        key_blocktrades =  'blocktrades.us   '
        key_coingecko =    'coingecko.com    '
        # key_hive_engine =  'hive-engine.com '
        ticker = {
          key_ionomy => nil,
          key_bittrex => nil,
          key_binance => nil,
          key_huobi => nil,
          key_probit => nil,
          key_blocktrades => nil,
          key_coingecko => nil,
          # key_hive_engine => nil
        }
        
        threads << Thread.new do
          begin
            _btx_market_data = btx_market_data
            btx_usdt_hive, btx_usdt_hbd = _btx_market_data[:usdt_hive], _btx_market_data[:usdt_hbd]
            btx_btc_hive, btx_btx_hbd = _btx_market_data[:btc_hive], _btx_market_data[:btc_hbd]

            btx_usdt_hive = number_to_currency(btx_usdt_hive, precision: 4).rjust(10)
            btx_usdt_hbd = number_to_currency(btx_usdt_hbd, precision: 4).rjust(10)
            btx_btc_hive = number_to_currency(btx_btc_hive, precision: 8, unit: '').rjust(10)
            btx_btx_hbd = number_to_currency(btx_btx_hbd, precision: 8, unit: '').rjust(10)

            ticker[key_bittrex] = "#{btx_usdt_hive} |  #{btx_usdt_hbd} | #{btx_btc_hive} |  #{btx_btx_hbd}"
          rescue => e
            puts e
          end
        end
        
        threads << Thread.new do
          begin
            bin_hive_usdt = JSON[open('https://api.binance.com/api/v1/ticker/price?symbol=HIVEUSDT').read].fetch('price').to_f
            bin_hive_btc = JSON[open('https://api.binance.com/api/v1/ticker/price?symbol=HIVEBTC').read].fetch('price').to_f
            bin_hive_usdt = number_to_currency(bin_hive_usdt, precision: 4).rjust(10)
            bin_hive_btc = number_to_currency(bin_hive_btc, precision: 8, unit: '').rjust(10)
            
            ticker[key_binance] = "#{bin_hive_usdt} |             | #{bin_hive_btc} |            "
          rescue => e
            puts e
          end
        end
        
        threads << Thread.new do
          begin
            hub_hive_usdt = JSON[open('https://api.huobi.pro/market/detail/merged?symbol=hiveusdt').read].fetch('tick').fetch('close').to_f
            hub_hive_btc = JSON[open('https://api.huobi.pro/market/detail/merged?symbol=hivebtc').read].fetch('tick').fetch('close').to_f
            hub_hive_usdt = number_to_currency(hub_hive_usdt, precision: 4).rjust(10)
            hub_hive_btc = number_to_currency(hub_hive_btc, precision: 8, unit: '').rjust(10)
            
            ticker[key_huobi] = "#{hub_hive_usdt} |             | #{hub_hive_btc} |            "
          rescue => e
            puts e
          end
        end
        
        threads << Thread.new do
          begin
            ionomy_market = JSON[open('https://ionomy.com/api/v1/public/markets-summaries').read].fetch('data')
            in_btc_hive = ionomy_market.find{|m| m.fetch('market') == 'btc-hive'}.fetch('price').to_f
            in_btc_hive = number_to_currency(in_btc_hive, precision: 8, unit: '').rjust(10)
            
            ticker[key_ionomy] = "           |             | #{in_btc_hive} |            "
          rescue => e
            puts e
          end
        end
        
        threads << Thread.new do
          begin
            probit_market = JSON[open('https://api.probit.com/api/exchange/v1/ticker?market_ids=HIVE-USDT').read].fetch('data')
            pb_usd_hive = probit_market.find{|m| m.fetch('market_id') == 'HIVE-USDT'}.fetch('last').to_f
            pb_usd_hive = number_to_currency(pb_usd_hive, precision: 4).rjust(10)
            
            ticker[key_probit] = "#{pb_usd_hive} |             |            |            "
          rescue => e
            puts e
          end
        end
        
        threads << Thread.new do
          begin
            # See: https://cryptofresh.com/a/TRADE.HIVE
            hive_market = JSON[open('https://cryptofresh.com/api/asset/markets?asset=TRADE.HIVE').read]
            # See: https://cryptofresh.com/a/TRADE.HBD
            hbd_market = JSON[open('https://cryptofresh.com/api/asset/markets?asset=TRADE.HIVE').read]
            btr_usd_hive = hive_market.fetch('TRADE.USDT', {}).fetch('price', '')
            btr_usd_hbd = hbd_market.fetch('TRADE.USDT', {}).fetch('price', '')
            btr_btc_hive = hive_market.fetch('TRADE.BTC', {}).fetch('price', '')
            btr_btc_hbd = hbd_market.fetch('TRADE.BTC', {}).fetch('price', '')
            
            btr_usd_hive = number_to_currency(btr_usd_hive, precision: 4).rjust(10)
            btr_usd_hbd = number_to_currency(btr_usd_hbd, precision: 4).rjust(10)
            btr_btc_hive = number_to_currency(btr_btc_hive, precision: 8, unit: '').rjust(10)
            btr_btc_hbd = number_to_currency(btr_btc_hbd, precision: 8, unit: '').rjust(10)
            
            if btr_usd_hive =~ /[0-9]+/ || btr_usd_hbd =~ /[0-9]+/ || btr_btc_hive =~ /[0-9]+/ || btr_btc_hbd =~ /[0-9]+/
              ticker[key_blocktrades] = "#{btr_usd_hive} |  #{btr_usd_hbd} | #{btr_btc_hive} |  #{btr_btc_hbd}"
            else
              ticker.delete(key_blocktrades)
            end
          rescue => e
            puts e
          end
        end
        
        threads << Thread.new do
          begin
            cg_hive = JSON[open('https://api.coingecko.com/api/v3/coins/hive').read] rescue {}
            cg_hbd = JSON[open('https://api.coingecko.com/api/v3/coins/hive_dollar').read] rescue {}
            cg_usd_hive = cg_hive.fetch('market_data').fetch('current_price').fetch('usd').to_f rescue -1
            cg_btc_hive = cg_hive.fetch('market_data').fetch('current_price').fetch('btc').to_f rescue -1
            cg_usd_hbd = cg_hbd.fetch('market_data').fetch('current_price').fetch('usd').to_f rescue -1
            cg_btc_hbd = cg_hbd.fetch('market_data').fetch('current_price').fetch('btc').to_f rescue -1
            
            cg_usd_hive = if cg_usd_hive == -1
              'N/A'
            else
              number_to_currency(cg_usd_hive, precision: 4)
            end.rjust(10)
            
            cg_usd_hbd = if cg_usd_hbd == -1
              'N/A'
            else
              number_to_currency(cg_usd_hbd, precision: 4)
            end.rjust(10)
            
            cg_btc_hive = if cg_btc_hive == -1
              'N/A'
            else
              number_to_currency(cg_btc_hive, precision: 8, unit: '')
            end.rjust(10)
            
            cg_btc_hbd = if cg_btc_hbd == -1
              'N/A'
            else
              number_to_currency(cg_btc_hbd, precision: 8, unit: '')
            end.rjust(10)
            
            ticker[key_coingecko] = "#{cg_usd_hive} |  #{cg_usd_hbd} | #{cg_btc_hive} |  #{cg_btc_hbd}"
          rescue => e
            puts e
          end
        end
        
        # threads << Thread.new do
        #   begin
        #     hive_history_data = hive_engine_contracts(:find, {
        #       contract: 'market',
        #       table: 'tradesHistory',
        #       query: {
        #         symbol: 'SWAP.HIVE'
        #       },
        #       limit: 1,
        #       offset: 0,
        #       indexes: [{index: '_id', descending: true}]
        #     })
        # 
        #     # btc_history_data = hive_engine_contracts(:find, {
        #     #   contract: 'market',
        #     #   table: 'tradesHistory',
        #     #   query: {
        #     #     symbol: 'SWAP.BTC'
        #     #   },
        #     #   limit: 1,
        #     #   offset: 0,
        #     #   indexes: [{index: '_id', descending: true}]
        #     # })
        # 
        #     cg_prices = JSON[open('https://api.coingecko.com/api/v3/simple/price?ids=HIVE&vs_currencies=USD').read]
        #     cg_usd_hive = cg_prices['hive']['usd']
        #     he_usd_hive = hive_history_data[0]['price'].to_f * cg_usd_hive
        #     # # se_hive_usd = btc_history_data[0]['price'].to_f * se_usd_hive
        #     # # se_btc_hive = se_usd_hive / se_hive_usd
        #     # se_usd_hive = number_to_currency(se_usd_hive, precision: 4).rjust(10)
        #     # # se_btc_hive = number_to_currency(se_btc_hive, precision: 8, unit: '').rjust(10)
        #     # 
        #     ticker[key_steem_engine] = "#{he_usd_hive} |             |            |            "
        #   rescue => e
        #     puts e
        #   end
        # end
      end
      
      start_typing event
      threads.each(&:join)
      
      render_ticker(message, event, ticker, chain)
    end
    
    def promoted(chain = :hive, period = :today)
      chain = chain.to_s.downcase.to_sym
      
      promoted = case chain
      # when :steem then SteemApi::Tx::Transfer.where(to: 'null', amount_symbol: 'SBD').send(period)
      when :hive then HiveSQL::Tx::Transfer.where(to: 'null', amount_symbol: 'HBD').send(period)
      else
        return "Query not supported.  No database for #{chain.to_s.capitalize}."
      end
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
    
    def supply(chain = :hive)
      chain ||= :hive
      chain = chain.to_s.downcase.to_sym
      base_per_mvest, base_per_debt = price_feed(chain)
      properties = api(chain).get_dynamic_global_properties do |_properties, error|
        _properties
      end
      
      current_supply = properties.current_supply.split(' ').first.to_f
      virtual_supply = properties.virtual_supply.split(' ').first.to_f
      debt_steem = virtual_supply - current_supply
      total_base = (current_supply / base_per_mvest) * base_per_debt
      ratio = (debt_steem / virtual_supply) * 100
      
      current_debt_supply, total_vesting_fund_base = case chain
        when :steem
          [
            properties.current_sbd_supply.split(' ').first.to_f,
            properties.total_vesting_fund_steem.split(' ').first.to_f
          ]
        when :hive
          [
            properties.current_hbd_supply.split(' ').first.to_f,
            properties.total_vesting_fund_hive.split(' ').first.to_f
          ]
      end
      
      supply = []
      case chain
      when :steem
        reward_balance = api(chain).get_reward_fund('post') do |reward_fund|
          reward_fund.reward_balance.split(' ').first.to_f
        end
        
        liquid_supply = current_supply - reward_balance - total_vesting_fund_base
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
        
        liquid_supply = current_supply - reward_balance - total_vesting_fund_base
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
        
        liquid_supply = current_supply - reward_balance - total_vesting_fund_base
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
      when :hive
        reward_balance = api(chain).get_reward_fund('post') do |reward_fund|
          reward_fund.reward_balance.split(' ').first.to_f
        end
        
        liquid_supply = current_supply - reward_balance - total_vesting_fund_base
        ratio_liquid = (liquid_supply / current_supply) * 100

        current_supply = number_with_precision(current_supply, precision: 0, delimiter: ',', separator: '.')
        ratio = number_to_percentage(ratio, precision: 3)
        total_base = number_to_currency(total_base, precision: 0)
        current_debt_supply = number_to_currency(current_debt_supply, precision: 0)
        liquid_supply = number_with_precision(liquid_supply, precision: 0, delimiter: ',', separator: '.')
        ratio_liquid = number_to_percentage(ratio_liquid, precision: 3)
      
        supply << ["#{current_supply} HIVE (Worth #{total_base} HBD)"]
        supply << ["#{current_debt_supply} HBD (#{ratio} of supply)"]
        supply << ["#{liquid_supply} Liquid HIVE (#{ratio_liquid} of supply)"]
      end
      
      "Supply: `" + supply.join('; ') + "`"
    end
    
    def mvests_sum(options = {})
      chain = options[:chain] || :hive
      chain = chain.to_s.downcase.to_sym
      account_names = options[:account_names]
      case chain
      # when :steem then SteemApi::Account.where(name: account_names).sum("TRY_PARSE(REPLACE(vesting_shares, ' VESTS', '') AS float)")
      when :golos then "Query not supported.  No database for Golos."
      when :test then "Query not supported.  No database for Testnet."
      when :hive then HiveSQL::Account.where(name: account_names).sum("TRY_PARSE(REPLACE(vesting_shares, ' VESTS', '') AS float)")
      end
    end
    
    def debt_exchange_rate(chain = :hive, limit = 19)
      chain ||= :hive
      chain = chain.to_s.downcase.to_sym
      rates = api(chain).get_witnesses_by_vote('', limit) do |witnesses|
        witnesses.map(&:sbd_exchange_rate)
      end
      
      symbol = case chain
      when :steem then 'SBD'
      when :golos then 'GBG'
      when :hive then 'HBD'
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
    
    def apr(chain = :hive, limit = 20)
      chain ||= :hive
      chain = chain.to_s.downcase.to_sym
      rates = api(chain).get_witnesses_by_vote('', limit) do |witnesses|
        witnesses.map(&:props).map { |p| p['sbd_interest_rate'] }
      end
      
      rate = rates.sum / rates.size
      rate = rate / 100.0
      number_to_percentage(rate, precision: 3)
    end
    
    def effective_apr(chain = :hive)
      chain ||= :hive
      chain = chain.to_s.downcase.to_sym
      rate = api(chain).get_dynamic_global_properties do |properties|
        properties.sbd_interest_rate
      end
      
      rate = rate / 100.0
      number_to_percentage(rate, precision: 3)
    end
    
    def effective_price(chain = :hive)
      chain ||= :hive
      chain = chain.to_s.downcase.to_sym
      current_median_history = api(chain).get_feed_history do |feed_history|
        feed_history.current_median_history
      end
      
      b = current_median_history.base.split(' ').first.to_f
      q = current_median_history.quote.split(' ').first.to_f
      
      symbol = case chain
      when :steem then 'SBD'
      when :golos then 'GBG'
      when :hive then 'HBD'
      end
      
      price = b / q
      price = number_with_precision(price, precision: 3, delimiter: ',', separator: '.')
      
      "#{price} #{symbol}"
    end
  end
end
