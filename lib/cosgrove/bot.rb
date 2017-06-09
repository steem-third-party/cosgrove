require 'discordrb'

module Cosgrove
  require 'cosgrove/snark_commands'
  
  class Bot < Discordrb::Commands::CommandBot
    include SnarkCommands
    
    def initialize(options = {})
      super
      
      Bot::add_all_commands(self)
      SnarkCommands::add_all_snark_commands(self)
    end
    
    def self.add_all_commands(bot)
      bot.command :version do |_|
        "cosgrove: #{Cosgrove::VERSION} :: https://github.com/steem-third-party/cosgrove"
      end
    end
  end
end
