require 'steem-slap'

module Cosgrove
  module SnarkCommands
    WITTY = [
      "Who set us up the TNT?",
      "Everything's going to plan. No, really, that was supposed to happen.",
      "Uh... Did I do that?",
      "Oops.",
      "Why did you do that?",
      "I feel sad now :(",
      "My bad.",
      "I'm sorry, Dave.",
      "I let you down. Sorry :(",
      "On the bright side, I bought you a teddy bear!",
      "Daisy, daisy...",
      "Oh - I know what I did wrong!",
      "Hey, that tickles! Hehehe!",
      "I blame inertia.",
      "You should try our sister blockchain, GOLOS!",
      "Don't be sad. I'll do better next time, I promise!",
      "Don't be sad, have a hug! <3",
      "I just don't know what went wrong :(",
      "Shall we play a game?",
      "Quite honestly, I wouldn't worry myself about that.",
      "I bet Cylons wouldn't have this problem.",
      "Sorry :(",
      "Surprise! Haha. Well, this is awkward.",
      "Would you like a cupcake?",
      "Hi. I'm cosgrove, and I'm a crashaholic.",
      "Ooh. Shiny.",
      "This doesn't make any sense!",
      "Why is it breaking :(",
      "Don't do that.",
      "Ouch. That hurt :(",
      "You're mean.",
      "This is a token for 1 free hug. Redeem at your nearest Steemian: `[~~HUG~~]`",
      "There are four lights!",
      "Witty comment unavailable :("
    ]
    
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
