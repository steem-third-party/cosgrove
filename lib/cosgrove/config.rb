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
    
    def steem_api_url
      chain[:steem_api_url]
    end
    
    def golos_api_url
      chain[:golos_api_url]
    end
    
    def test_api_url
      chain[:test_api_url]
    end
    
    def steem_account
      chain[:steem_account]
    end
    
    def steem_posting_wif
      chain[:steem_posting_wif]
    end
    
    def golos_account
      chain[:golos_account]
    end
    
    def golos_posting_wif
      chain[:golos_posting_wif]
    end
    
    def test_posting_wif
      chain[:test_posting_wif]
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
  private
    def chain
      @chain ||= yml[:chain]
    end
    
    def yml
      return @yml if !!@yml
      
      config_yaml_path = "config.yml"
      
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
