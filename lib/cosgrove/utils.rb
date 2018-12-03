module Cosgrove
  module Utils
    include Config
    
    def cycle_api_at
      @cycle_api_at if defined? @cycle_api_at
    end
    
    def reset_api
      @steem_api = @golos_api = @test_api = nil
      @steem_folow_api = @golos_follow_api = @test_folow_api = nil
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
      when :golos
        {
          chain: :golos,
          url: golos_api_url,
          failover_urls: golos_api_failover_urls.any? ? golos_api_failover_urls : nil
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
      when :golos then @golos_api ||= Radiator::Api.new(chain_options(chain))
      when :test then @test_api ||= Radiator::Api.new(chain_options(chain))
      end
    end
    
    def follow_api(chain)
      reset_api if cycle_api_at.nil? || cycle_api_at < 15.minutes.ago
      
      @cycle_api_at ||= Time.now
      
      case chain
      when :steem then @steem_follow_api ||= Radiator::FollowApi.new(chain_options(chain))
      when :golos then @golos_follow_api ||= Radiator::FollowApi.new(chain_options(chain))
      when :test then @test_follow_api ||= Radiator::FollowApi.new(chain_options(chain))
      end
    end
    
    def cycle_stream_at
      @cycle_stream_at if defined? @cycle_stream_at
    end
    
    def reset_stream
      @steem_stream = @golos_stream = @test_stream = nil
      @steem_folow_stream = @golos_follow_stream = @test_folow_stream = nil
      @cycle_stream_at = nil
    end
    
    def stream(chain)
      reset_stream if cycle_stream_at.nil? || cycle_stream_at < 15.minutes.ago
      
      @cycle_stream_at ||= Time.now
      
      case chain
      when :steem then @steem_stream ||= Radiator::Stream.new(chain_options(chain))
      when :golos then @golos_stream ||= Radiator::Stream.new(chain_options(chain))
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
      when :golos then Radiator::Transaction.new(chain_options(chain).merge(wif: golos_posting_wif))
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
    
    def find_author_name_permlink(slug)
      op, author_name = slug.split(':')
      author_name, offset = author_name.split(/[\+-]/)
      author = find_account(author_name)
      
      offset = offset.to_i
      
      posts = if op == 'latest'
        SteemApi::Comment.where(depth: 0, author: author.name).order(created: :desc)
      elsif op == 'first'
        SteemApi::Comment.where(depth: 0, author: author.name).order(created: :asc)
      else
        []
      end
      
      if posts.any? && !!(post = posts[offset.to_i.abs])
        return [author_name, post.permlink]
      end
      
      []
    end
    
    def find_comment_by_slug(slug)
      author_name, permlink = parse_slug slug
      find_comment(chain: :steem, author_name: author_name, permlink: permlink)
    end
    
    def find_comment(options)
      chain = options[:chain] || :steem
      author_name = options[:author_name]
      permlink = options[:permlink]
      parent_permlink = options[:parent_permlink]
      
      post = if chain == :steem
        posts = SteemApi::Comment.where(depth: 0, author: author_name)
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
        # when :golos
        #   posts = GolosCloud::Comment.where(author: author_name)
        #   posts = posts.where(permlink: permlink) if !!permlink
        #   posts = posts.where(parent_permlink: parent_permlink) if !!parent_permlink
        # 
        #   posts.first
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
      chain = options[:chain]
      author_name = options[:author_name]
      
      author = SteemApi::Account.where(name: author_name).first
      
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
      when :golos
        GolosCloud::Tx::Transfer.
          where(from: from).
          where(to: to).
          where("memo LIKE ?", "%#{memo_key}%").last
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
      case chain
      when :steem then 'STEEM'
      when :golos then 'GOLOS'
      else; 'TESTS'
      end
    end
    
    def debt_asset(chain = :steem)
      case chain
      when :steem then 'SBD'
      when :golos then 'GBG'
      else; 'TBD'
      end
    end
  end
end
