require 'digest/bubblebabble'
require "yaml/store"

module Cosgrove
  class Account
    include Config
    include Utils

    ACCOUNTS_FILE ||= "#{Cosgrove::PWD}/accounts.yml".freeze
    DISCORD_IDS = 'discord_ids'.freeze
    
    attr_accessor :account_name, :discord_ids
    
    def initialize(account_name, chain = :hive)
      @chain = chain.to_sym
      raise "Unknown Chain: #{@chain}" unless Cosgrove::KNOWN_CHAINS.include? @chain
      
      @account_name = account_name.to_s.downcase
      @discord_ids = []
      
      if !!details
        @discord_ids = details[DISCORD_IDS] || []
      end
    end
    
    def self.find_by_discord_id(discord_id, chain = :hive)
      return if Account.chain_data(chain.to_s).nil?
      
      discord_id = discord_id.to_s.split('@').last.split('>').first.to_i
      
      return nil if discord_id == 0
      
      Account.chain_data(chain.to_s).each do |k, v|
        ids = v[DISCORD_IDS]
        return Account.new(k, chain) if !!ids && ids.include?(discord_id)
      end
      
      return nil
    end
    
    def self.find_by_memo_key(memo_key, secure, chain = :hive)
      Account.chain_data(chain.to_s).each do |k, v|
        v[DISCORD_IDS].each do |discord_id|
          return Account.new(k, chain) if Account.gen_memo_key(k, discord_id, secure, chain) == memo_key
        end
      end
      
      return nil
    end
    
    def details(chain = :hive)
      Account.chain_data(chain.to_s)[@account_name] ||= {}
      Account.chain_data(chain.to_s)[@account_name]
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
      
      Account.save_chain_data!(:hive)
    end
    
    def memo_key(discord_id)
      Account.gen_memo_key(@account_name, discord_id, cosgrove_secure, @chain)
    end
    
    def chain_account
      return @chain_account if !!@chain_account
      
      if !!@account_name
        api(@chain).get_accounts([@account_name]) do |accounts, errors|
          @chain_account = accounts.first
        end
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
    
    def self.store
      @store ||= YAML::Store.new(ACCOUNTS_FILE)
    end
    
    def self.save_chain_data!(chain, data = @chain_data)
      store.transaction {
        store[chain] = data
      }
    end
    
    def self.chain_data(chain)
      store.transaction {
        @chain_data = store[chain] || {}
      }
    end
  end
end
