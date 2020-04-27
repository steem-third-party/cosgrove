module Cosgrove
  module Utils
    include Config
    
    def cycle_api_at
      @cycle_api_at if defined? @cycle_api_at
    end
    
    def reset_api
      @steem_api = @hive_api = @test_api = nil
      @steem_follow_api = @hive_follow_api = @test_follow_api = nil
      @cycle_api_at = nil
    end
    
    def ping_api(chain)
      api(chain).get_config do |config, errors|
        reset_api if !!errors || config.keys.none?
      end
      
      true
    end
    
    def chain_options(chain)
      case chain
      when :steem
        {
          chain: :steem,
          url: steem_api_url,
          failover_urls: steem_api_failover_urls.any? ? steem_api_failover_urls : nil
        }
      when :hive
        {
          chain: :steem, # TODO switch to :hive when supported by radiator
          url: hive_api_url,
          failover_urls: hive_api_failover_urls.any? ? hive_api_failover_urls : nil
        }
      when :test
        {
          chain: :test,
          url: test_api_url,
          failover_urls: test_api_failover_urls
        }
      end
    end
    
    def api(chain)
      reset_api if cycle_api_at.nil? || cycle_api_at < 15.minutes.ago
      
      @cycle_api_at ||= Time.now
      
      case chain
      when :steem then @steem_api ||= Radiator::Api.new(chain_options(chain))
      when :hive then @hive_api ||= Radiator::Api.new(chain_options(chain))
      when :test then @test_api ||= Radiator::Api.new(chain_options(chain))
      end
    end
    
    def follow_api(chain)
      reset_api if cycle_api_at.nil? || cycle_api_at < 15.minutes.ago
      
      @cycle_api_at ||= Time.now
      
      case chain
      when :steem then @steem_follow_api ||= Radiator::FollowApi.new(chain_options(chain))
      when :hive then @hive_follow_api ||= Radiator::FollowApi.new(chain_options(chain))
      when :test then @test_follow_api ||= Radiator::FollowApi.new(chain_options(chain))
      end
    end
    
    def steem_engine_shutdown
      problem = false
      
      begin
        @steem_engine_blockchain.shutdown if !!@steem_engine_blockchain
      rescue => e
        puts "Unable to shut down steem engine blockchain rpc: #{e}"
        problem = true
      end
      
      begin
        @steem_engine_contracts.shutdown if !!@steem_engine_contracts
      rescue => e
        puts "Unable to shut down steem engine contracts rpc: #{e}"
        problem = true
      end
      
      !problem
    end
    
    def steem_engine(method, params = {}, rpc)
      begin
        if params.respond_to?(:empty?) && params.empty?
          rpc.send(method)
        else
          rpc.send(method, params)
        end
      rescue => e
        steem_engine_shutdown
        
        raise e
      end
    end
    
    def steem_engine_blockchain(method, params = {}, &block)
      @steem_engine_blockchain ||= Radiator::SSC::Blockchain.new(root_url: steem_engine_api_url)
      result = steem_engine(method, params, @steem_engine_blockchain)
      
      yield result if !!block
      return result
    end
    
    def steem_engine_contracts(method, params = {}, &block)
      @steem_engine_contracts ||= Radiator::SSC::Contracts.new(root_url: steem_engine_api_url)
      result = steem_engine(method, params, @steem_engine_contracts)
      
      yield result if !!block
      return result
    end
    
    def hive_engine_shutdown
      problem = false
      
      begin
        @hive_engine_blockchain.shutdown if !!@hive_engine_blockchain
      rescue => e
        puts "Unable to shut down hive engine blockchain rpc: #{e}"
        problem = true
      end
      
      begin
        @hive_engine_contracts.shutdown if !!@hive_engine_contracts
      rescue => e
        puts "Unable to shut down hive engine contracts rpc: #{e}"
        problem = true
      end
      
      !problem
    end
    
    def hive_engine(method, params = {}, rpc)
      begin
        if params.respond_to?(:empty?) && params.empty?
          rpc.send(method)
        else
          rpc.send(method, params)
        end
      rescue => e
        hive_engine_shutdown
        
        raise e
      end
    end
    
    def hive_engine_blockchain(method, params = {}, &block)
      @hive_engine_blockchain ||= Radiator::SSC::Blockchain.new(root_url: hive_engine_api_url)
      result = hive_engine(method, params, @hive_engine_blockchain)
      
      yield result if !!block
      return result
    end
    
    def hive_engine_contracts(method, params = {}, &block)
      @hive_engine_contracts ||= Radiator::SSC::Contracts.new(root_url: hive_engine_api_url)
      result = hive_engine(method, params, @hive_engine_contracts)
      
      yield result if !!block
      return result
    end
    
    def cycle_stream_at
      @cycle_stream_at if defined? @cycle_stream_at
    end
    
    def reset_stream
      @steem_stream = @hive_stream = @test_stream = nil
      @steem_follow_stream = @hive_follow_stream = @test_follow_stream = nil
      @cycle_stream_at = nil
    end
    
    def stream(chain)
      reset_stream if cycle_stream_at.nil? || cycle_stream_at < 15.minutes.ago
      
      @cycle_stream_at ||= Time.now
      
      case chain
      when :steem then @steem_stream ||= Radiator::Stream.new(chain_options(chain))
      when :hive then @hive_stream ||= Radiator::Stream.new(chain_options(chain))
      when :test then @test_stream ||= Radiator::Stream.new(chain_options(chain))
      end
    end
    
    def properties(chain)
      api(chain).get_dynamic_global_properties.result
    end
    
    def head_block_number(chain)
      properties(chain)['head_block_number']
    end
    
    def last_irreversible_block_num(chain = :steem)
      properties(chain)['last_irreversible_block_num']
    end
    
    def new_tx(chain)
      case chain
      when :steem then Radiator::Transaction.new(chain_options(chain).merge(wif: steem_posting_wif))
      when :hive then Radiator::Transaction.new(chain_options(chain).merge(wif: hive_posting_wif))
      when :test then Radiator::Transaction.new(chain_options(chain).merge(wif: test_posting_wif))
      end
    end
    
    def to_rep(raw)
      raw = raw.to_i
      neg = raw < 0
      level = Math.log10(raw.abs)
      level = [level - 9, 0].max
      level = (neg ? -1 : 1) * level
      level = (level * 9) + 25

      '%.2f' % level
    end
    
    def parse_slug(slug)
      case slug
      when /^latest:/ then find_author_name_permlink(slug)
      when /^first:/ then find_author_name_permlink(slug)
      else
        slug = slug.split('@').last
        author_name = slug.split('/')[0]
        permlink = slug.split('/')[1..-1].join('/')
        permlink = permlink.split('#')[0]
        
        [author_name, permlink]
      end
    end
    
    def find_author_name_permlink(slug, chain = :steem)
      chain = chain.to_s.downcase.to_sym
      op, author_name = slug.split(':')
      author_name, offset = author_name.split(/[\+-]/)
      author = find_account(author_name, nil, chain)
      
      offset = offset.to_i
      
      posts = if op == 'latest'
        case chain
        when :steem then SteemApi::Comment.where(depth: 0, author: author.name).order(created: :desc)
        when :hive then HiveSQL::Comment.where(depth: 0, author: author.name).order(created: :desc)
        end
      elsif op == 'first'
        case chain
        when :steem then SteemApi::Comment.where(depth: 0, author: author.name).order(created: :asc)
        when :hive then HiveSQL::Comment.where(depth: 0, author: author.name).order(created: :asc)
        end
      else
        []
      end
      
      if posts.any? && !!(post = posts[offset.to_i.abs])
        return [author_name, post.permlink]
      end
      
      []
    end
    
    def find_comment_by_slug(slug, chain = :steem)
      chain ||= :steem
      chain = chain.to_s.downcase.to_sym
      author_name, permlink = parse_slug slug
      find_comment(chain: chain, author_name: author_name, permlink: permlink)
    end
    
    def find_comment(options)
      chain = options[:chain] || :steem
      chain = chain.to_s.downcase.to_sym
      author_name = options[:author_name]
      permlink = options[:permlink]
      parent_permlink = options[:parent_permlink]
      
      post = if chain == :steem
        posts = SteemApi::Comment.where(depth: 0, author: author_name)
        posts = posts.where(permlink: permlink) if !!permlink
        posts = posts.where(parent_permlink: parent_permlink) if !!parent_permlink
        
        posts.first
      elsif chain == :hive
        posts = HiveSQL::Comment.where(depth: 0, author: author_name)
        posts = posts.where(permlink: permlink) if !!permlink
        posts = posts.where(parent_permlink: parent_permlink) if !!parent_permlink
        
        posts.first
      end
      
      if post.nil?
        post = case chain
        when :steem
          posts = SteemApi::Comment.where(author: author_name)
          posts = posts.where(permlink: permlink) if !!permlink
          posts = posts.where(parent_permlink: parent_permlink) if !!parent_permlink
          
          posts.first
        when :hive
          posts = HiveSQL::Comment.where(author: author_name)
          posts = posts.where(permlink: permlink) if !!permlink
          posts = posts.where(parent_permlink: parent_permlink) if !!parent_permlink
          
          posts.first
        end
      end
      
      if post.nil? && !!author_name && !!permlink
        # Fall back to RPC
        api(chain).get_content(author_name, permlink) do |content, errors|
          unless content.author.empty?
            post = content
          end
        end
      end
      
      post
    end
    
    def find_author(options)
      chain = options[:chain] || :steem
      chain = chain.to_s.downcase.to_sym
      author_name = options[:author_name]
      
      author = case chain
      when :steem then SteemApi::Account.where(name: author_name).first
      when :hive then HiveSQL::Account.where(name: author_name).first
      end
      
      if author.nil?
        author = api(chain).get_accounts([author_name]) do |accounts, errors|
          accounts.first
        end
      end
      
      author
    end
    
    def find_transfer(options)
      chain = options[:chain]
      from = options[:from]
      to = options[:to]
      memo_key = options[:memo].to_s.strip
      
      op = case chain
      when :steem
        transfers = SteemApi::Tx::Transfer.
          where(from: from, to: steem_account).
          where("memo LIKE ?", "%#{memo_key}%")
      
        if transfers.any?
          transfers.last
        else
          SteemApi::Tx::Transfer.
            where(from: from).
            where(to: to).
            where("memo LIKE ?", "%#{memo_key}%").last
        end
      when :hive
        transfers = HiveSQL::Tx::Transfer.
          where(from: from, to: steem_account).
          where("memo LIKE ?", "%#{memo_key}%")
      
        if transfers.any?
          transfers.last
        else
          HiveSQL::Tx::Transfer.
            where(from: from).
            where(to: to).
            where("memo LIKE ?", "%#{memo_key}%").last
        end
      end
      
      if op.nil?
        # Fall back to RPC.  The transaction is so new, SteemApi hasn't seen it
        # yet, SteemApi is behind, or there is no such transfer.
        
        api(chain).get_account_history(steem_account, -1, 10000) do |history, error|
          if !!error
            ap error
            return "Try again later."
          end
          
          op = history.map do |trx|
            e = trx.last.op
            type = e.first
            next unless type == 'transfer'
            o = e.last
            next unless o.from == from
            next unless o.to == steem_account
            next unless o.memo =~ /.*#{memo_key}.*/
            
            o
          end.compact.last
        end
      end

      op
    end
    
    def core_asset(chain = :steem)
      chain ||= :steem
      chain = chain.to_s.downcase.to_sym
      
      case chain
      when :steem then 'STEEM'
      when :hive then 'HIVE'
      else; 'TESTS'
      end
    end
    
    def debt_asset(chain = :steem)
      chain ||= :steem
      chain = chain.to_s.downcase.to_sym
      
      case chain
      when :steem then 'SBD'
      when :hive then 'HBD'
      else; 'TBD'
      end
    end
  private
    def rpc_id
      @rpc_id ||= 0
      @rpc_id += 1
    end
  end
end
