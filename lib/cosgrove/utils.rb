module Cosgrove
  module Utils
    include Cosgrove::Config
    
    def reset_api
      @steem_api = @golos_api = @test_api = nil
      @steem_folow_api = @golos_follow_api = @test_folow_api = nil
      @cycle_api_at = nil
    end
    
    def ping_api(chain)
      response = api(chain).get_config
      
      reset_api if !!response.error
      
      result = response.result
      reset_api unless result.keys.any?
      
      true
    end
    
    def api(chain)
      reset_api if @cycle_api_at.nil? || @cycle_api_at < 15.minutes.ago
      
      @cycle_api_at ||= Time.now
      
      case chain
      when :steem then @steem_api ||= Radiator::Api.new(chain: :steem, url: steem_api_url)
      when :golos then @golos_api ||= Radiator::Api.new(chain: :golos, url: golos_api_url)
      when :test then @test_api ||= Radiator::Api.new(chain: :test, url: test_api_url)
      end
    end
    
    def follow_api(chain)
      reset_api if @cycle_api_at.nil? || @cycle_api_at < 15.minutes.ago
      
      @cycle_api_at ||= Time.now
      
      case chain
      when :steem then @steem_follow_api ||= Radiator::FollowApi.new(chain: :steem, url: steem_api_url)
      when :golos then @golos_follow_api ||= Radiator::FollowApi.new(chain: :golos, url: golos_api_url)
      when :test then @test_follow_api ||= Radiator::FollowApi.new(chain: :test, url: test_api_url)
      end
    end
    
    def reset_stream
      @steem_stream = @golos_stream = @test_stream = nil
      @steem_folow_stream = @golos_follow_stream = @test_folow_stream = nil
      @cycle_stream_at = nil
    end
    
    def stream(chain)
      reset_stream if @cycle_stream_at.nil? || @cycle_stream_at < 15.minutes.ago
      
      @cycle_stream_at ||= Time.now
      
      case chain
      when :steem then @steem_stream ||= Radiator::Stream.new(url: steem_api_url)
      when :golos then @golos_stream ||= Radiator::Stream.new(url: golos_api_url)
      when :test then @test_stream ||= Radiator::Stream.new(url: test_api_url)
      end
    end
    
    def steem_data_head_block_number
      latest_settings_block = begin
        SteemData::Setting.last.last_block
      rescue => e
        ap e
        -1
      end
      
      latest_account_op_block = begin
        SteemData::AccountOperation.today.last.block
      rescue => e
        ap e
        -1
      end
      
      latest_op_block = begin
        SteemData::Operation.today.last.block_num
      rescue => e
        ap e
        -1
      end
      
      [latest_settings_block, latest_account_op_block, latest_op_block].min
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
      when :steem then Radiator::Transaction.new(chain: :steem, wif: steem_posting_wif, url: steem_api_url)
      when :golos then Radiator::Transaction.new(chain: :golos, wif: golos_posting_wif, url: golos_api_url)
      when :test then Radiator::Transaction.new(chain: :test, wif: test_posting_wif, url: test_api_url)
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
        
        [author_name, permlink]
      end
    end
    
    def find_author_name_permlink(slug)
      op, author_name = slug.split(':')
      author_name, offset = author_name.split(/[\+-]/)
      author = find_account(author_name)
      
      offset = offset.to_i
      
      posts = if op == 'latest'
        SteemData::Post.root_posts.where(author: author.name).order(created: :desc)
      elsif op == 'first'
        SteemData::Post.root_posts.where(author: author.name).order(created: :asc)
      else
        []
      end
      
      if posts.any? && !!(post = posts[offset.to_i.abs])
        return [author_name, post.permlink]
      end
      
      []
    end
  end
end
