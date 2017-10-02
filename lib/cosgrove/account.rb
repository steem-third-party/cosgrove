require 'digest/bubblebabble'

module Cosgrove
  class Account
    include Cosgrove::Config
    include Cosgrove::Utils

    ACCOUNTS_FILE ||= "#{Cosgrove::PWD}/accounts.yml".freeze
    DISCORD_IDS = 'discord_ids'.freeze
    
    attr_accessor :chain, :account_name, :discord_ids
    
    def initialize(account_name, chain = :steem)
      raise "Unknown Chain: #{chain}" unless Cosgrove::KNOWN_CHAINS.include? chain.to_sym
      
      @account_name = account_name.to_s.downcase
      @chain = chain
      @discord_ids = []
      
      if !!details
        @discord_ids = details[DISCORD_IDS] || []
      end
    end
    
    def self.find_by_discord_id(discord_id, chain = :steem)
      return if Account.yml[chain.to_s].nil?
      
      discord_id = discord_id.to_s.split('@').last.split('>').first.to_i
      
      Account.yml[chain.to_s].each do |k, v|
        ids = v[DISCORD_IDS]
        return Account.new(k, chain) if !!ids && ids.include?(discord_id)
      end
      
      return nil
    end
    
    def self.find_by_memo_key(memo_key, secure, chain = :steem)
      Account.yml[chain.to_s].each do |k, v|
        v[DISCORD_IDS].each do |discord_id|
          return Account.new(k, chain) if Account.gen_memo_key(k, discord_id, chain, secure) == memo_key
        end
      end
      
      return nil
    end
    
    def chain_data
      @chain_data ||= Account.yml[@chain.to_s] || {}
    end
    
    def details
      chain_data[@account_name] ||= {}
      chain_data[@account_name]
    end
    
    def hidden?
      !!details['hidden']
    end
    
    def novote?
      !!details['novote']
    end
    
    def add_discord_id(discord_id)
      details[DISCORD_IDS] ||= []
      details[DISCORD_IDS] << discord_id.to_i
      details[DISCORD_IDS] = details[DISCORD_IDS].uniq
      
      Account.save_yml!
    end
    
    def memo_key(discord_id)
      Account.gen_memo_key(@account_name, discord_id, cosgrove_secure, @chain)
    end
    
    def chain_account
      if !!@account_name
        response = api(chain).get_accounts([@account_name])
        account = response.result.first
      end
    end
  private
    def self.gen_memo_key(account_name, discord_id, secure, chain)
      raise "Unknown Chain: #{chain}" unless Cosgrove::KNOWN_CHAINS.include? chain.to_sym
      
      Digest.bubblebabble(Digest::SHA1::hexdigest(account_name + discord_id.to_s + chain.to_s + secure)[8..12])
    end
    
    def self.save_yml!
      return unless !!@yml
      
      File.open(ACCOUNTS_FILE, 'w+') do |f|
        f.write @yml.to_yaml
      end
    end
    
    def self.yml
      @yml = if File.exist?(ACCOUNTS_FILE)
        YAML.load_file(ACCOUNTS_FILE)
      else
        # Initialize
        File.open(ACCOUNTS_FILE, 'w+') do |f|
          f.write {}.to_yaml
        end
        {}
      end
    end
  end
end
