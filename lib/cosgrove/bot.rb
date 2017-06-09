require 'discordrb'

module Cosgrove
  class Bot < Discordrb::Commands::CommandBot
    def initiaize(options = {})
      super
      
      add_commands
    end
    
  private
    def add_commands
      command :version do |_|
        "cosgrove: #{Cosgrove::VERSION} :: #{https://github.com/steem-third-party/cosgrove}"
      end
    end
  end
end
