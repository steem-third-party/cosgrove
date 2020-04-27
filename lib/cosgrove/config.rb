module Cosgrove
  module Config
    def cosgrove_secure
      yml[:cosgrove][:secure]
    end
    
    def cosgrove_token
      yml[:cosgrove][:token]
    end
    
    def cosgrove_client_id
      yml[:cosgrove][:client_id]
    end
    
    def cosgrove_operators
      (yml[:cosgrove][:operators] || '').split(' ')
    end
    
    def cosgrove_allow_pm_commands
      yml[:cosgrove][:allow_pm_commands].to_s == 'true'
    end
    
    def cosgrove_upvote_weight
      yml[:cosgrove][:upvote_weight]
    end
    
    def cosgrove_disable_comment_voting
      yml[:cosgrove][:disable_comment_voting].to_s == 'true'
    end
    
    def steem_api_url
      chain[:steem_api_url]
    end
    
    def steem_api_failover_urls
      [chain[:steem_api_failover_urls]].flatten.compact
    end
    
    def hive_api_url
      chain[:hive_api_url]
    end
    
    def hive_api_failover_urls
      [chain[:hive_api_failover_urls]].flatten.compact
    end
    
    def test_api_url
      chain[:test_api_url]
    end
    
    def test_api_failover_urls
      [chain[:test_api_failover_urls]].flatten.compact
    end
    
    def steem_engine_api_url
      (chain[:steem_engine_api_url] rescue nil) || 'https://api.steem-engine.com/rpc'
    end
    
    def hive_engine_api_url
      (chain[:hive_engine_api_url] rescue nil) || 'https://api.hive-engine.com/rpc'
    end
    
    def steem_account
      chain[:steem_account]
    end
    
    def steem_posting_wif
      chain[:steem_posting_wif]
    end
    
    def hive_account
      chain[:hive_account]
    end
    
    def hive_posting_wif
      chain[:hive_posting_wif]
    end
    
    def test_posting_wif
      chain[:test_posting_wif]
    end
    
    def meeseeker_url
      chain[:meeseeker][:url]
    end
    
    def discord_channels
      return ENV['CHANNELS'].to_s.split(' ') if !!ENV['CHANNELS']
      
      yml[:discord][:channels]
    end
    
    def discord_log_mode
      return :debug if !!ENV['HELL_ENABLED']
      return :info unless !!yml[:discord][:log_mode]
      
      yml[:discord][:log_mode].to_sym
    end
    
    def discord_fancy_log
      return false if !!ENV['HELL_ENABLED']
      
      yml[:discord][:fancy_log].to_s == 'true'
    end
    
    def channel_upvote_weight(channel_id)
      rules = yml[:cosgrove][:upvote_rules][:channels]
      default_weight = rules[:default][:upvote_weight] rescue '0.00 %'
      
      keys = rules.keys - [:default]
      
      weight = keys.map do |key|
        rule = rules[key]
        rule[:upvote_weight] if rule[:channel_id] == channel_id
      end.compact.last
      
      weight || default_weight
    end
    
    def channel_disable_comment_voting(channel_id)
      rules = yml[:cosgrove][:upvote_rules][:channels]
      default_disable_comment_voting = rules[:default][:disable_comment_voting].to_s == 'true' rescue false
      
      keys = rules.keys - [:default]
      
      disable_comment_voting = keys.map do |key|
        rule = rules[key]
        rule[:disable_comment_voting] if rule[:channel_id] == channel_id
      end.compact.last
      
      disable_comment_voting || default_disable_comment_voting
    end
  private
    def chain
      @chain_hash ||= yml[:chain]
    end
    
    def yml
      return @yml if !!@yml
      
      config_yaml_path = "#{Cosgrove::PWD}/config.yml"
      
      @yml = if File.exist?(config_yaml_path)
        YAML.load_file(config_yaml_path)
      else
        raise "Create a file: #{config_yaml_path}"
      end
      
      if @yml[:cosgrove].nil? || @yml[:cosgrove][:secure].nil? || @yml[:cosgrove][:secure] == 'set this'
        raise "Set secure key in #{config_yaml_path}."
      end
      
      @yml
    end
  end
end
