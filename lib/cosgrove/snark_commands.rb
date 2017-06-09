module Cosgrove
  module SnarkCommands
    def self.add_all_snark_commands(bot)
      bot.command :slap do |_event, *target|
        if target.any?
          "*#{SteemSlap.slap(target.join(' '))}*"
        else
          "There are #{SteemSlap::combinations} slap combinations, see: https://gist.github.com/inertia186/c34e6e7b73f7ee9fb5f60f5ed8f30206"
        end
      end
    end
  end
end