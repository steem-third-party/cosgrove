# [Cosgrove](https://github.com/steem-third-party/cosgrove)

Cosgrove is a STEEM Centric Discord Bot Framework that allows you to write your own Discord bots that interact with the STEEM blockchain.

One example of a bot that uses this framework is [@banjo](https://steemit.com/steemdata/@inertia/introducing-banjo) on SteemSpeak.

## New features
  
* Engine support provided by the `Cosgrove::Utils` module.
* Bug fixes
* Gem updates.

## Features

* **Registration**
  * `$register <account> [chain]` - associate `account` with your Discord user (`chain` default `steem`)
* **Verification**
  * `$verify <account> [chain]` - check `account` association with Discord users (`chain` default `steem`)
* **Up Voting**
  * `$upvote [url]` - upvote from cosgrove; empty or `^` to upvote last steemit link
  * The ability for each discord channel to have its own upvote weight, as well as have a default.  Upvote voting weight can be:
    * `dynamic` - uses the bot's current voting recharge percent as the upvote percent.
    * `upvote_rules` - uses channel specific rules.
    * `100.00 %` - can be any valid voting percentage.
    * `disable_comment_voting` - only posts can get votes.
  * `CommentJob` for creating automated replies.
  * Callback `on_success_upvote_job` which can be used to, for example, reply to the post after being upvoted.
  * Market data now uses Bittrex instead of Poloniex.
  * `operators` to keep track of steem accounts that can do things like block upvotes (by blockchain mute).
  * Support for HiveSQL
  * Optimized interactive messages to update as data is acquired in realtime

## Installation

```bash
$ gem install cosgrove
```

... or in your `Gemfile`

```ruby
source 'https://rubygems.org'

gem 'cosgrove'
```

## Setup

Add a config file to your `ruby` project called `config.yml`:

```yaml
:cosgrove:
  :token: 
  :client_id: 
  :secure: set this
  :operators: <account names seperated by space>
  :upvote_weight: upvote_rules
  :upvote_rules:
    :channels:
      :default:
        :upvote_weight: 50.00 %
      :general_text:
        :channel_id: <Your Favorite Channel ID>
        :upvote_weight: 100.00 %
        :disable_comment_voting: true
:chain:
  :steem_account: 
  :steem_posting_wif: 
  :steem_api_url: https://api.steemit.com
  :steem_engine_api_url: https://api.steem-engine.com/rpc
  :hive_engine_api_url: https://api.hive-engine.com/rpc
  :hive_account: 
  :hive_posting_wif: 
  :hive_api_url: https://api.steem.house
:discord:
  :log_mode: info
```

You will need to request a `token` and `client_id` from Discord (see below).

Provide the accounts and `wif` private postings keys if you want your bot to upvote posts.

You should change the `secure` key using the output of:

```ruby
SecureRandom.hex(32)
```

## Bot Registration

1. Request a new bot here: https://discordapp.com/developers/applications/me#top
2. Register an `application` and create an `app bot user`.
3. Replace `APP_CLIENT_ID` with the App's Client ID in this URL: https://discordapp.com/oauth2/authorize?&client_id=APP_CLIENT_ID&scope=bot&permissions=153600
4. Give that URL to the Discord server/guild owner and have them authorize the bot.
5. Set the `token` and `client_id` in your bot constructor (see below).

## HiveSQL

Some features provided by `cosgrove` require access to [HiveSQL](http://hivesql.io/), which is a Microsoft SQL database containing all the Steem blockchain data.

**Please note:**

If you intend to use HiveSQL, you can provide the credentials in `authorize-hive-sql.sh`, then use this terminal command to enable HiveSQL just before running your bot.  Copy the example `example-authorize-hive-sql.sh` and add your credentials:

```bash
source path/to/authorize-hive-sql.sh
```

Features that currently require HiveSQL:

* Details in `$mvests` command
* Any command that tries to suggest account names
* `$upvote` (when checking for dailly limits)

## Usage

Cosgrove is based on `discordrb`, see: https://github.com/meew0/discordrb

All features offered by `discordrb` are available in Cosgrove.  In addition, Cosgrove comes with pre-defined commands.  See them by typing: `$help`

You can add you features thusly:

```ruby
require 'cosgrove'

bot = Cosgrove::Bot.new

bot.message(with_text: 'Ping!') do |event|
  event.respond 'Pong!'
end

bot.run
```

### Engine Lookups

Here's an example of a bot that does Engine API calls when you type: `$bal ENG alice`

```ruby
require 'cosgrove'

include Cosgrove::Utils

bot = Cosgrove::Bot.new

bot.command :bal do |event, *args|
  symbol = args[0].strip.upcase
  account = args[0].strip.downcase
  params = {
    query: {
      symbol: symbol,
      account: account
    }
  }
  result = steem_engine_contracts(:findOne, params)
  
  "#{result['balance']}'s '#{result['symbol']}: #{result['balance']}"
end

bot.run
```

## Tests

* Clone the client repository into a directory of your choice:
  * `git clone git@github.com:steem-third-party/cosgrove.git`
* Navigate into the new folder
  * `cd cosgrove`
* Basic tests can be invoked as follows:
  * `rake`
* To run tests with parallelization and local code coverage:
  * `HELL_ENABLED=true rake`

---

<center>
  <img src="http://i.imgur.com/7V09fNf.jpg" />
</center>

See my previous Ruby How To posts in: [#radiator](https://steemit.com/created/radiator) [#ruby](https://steemit.com/created/ruby)

Also see:
* [Cosgrove: Database Update](https://steemit.com/radiator/@inertia/cosgrove-database-update)
* [Introducing: Cosgrove - A STEEM Centric Discord Bot Framework](https://steemit.com/radiator/@inertia/introducing-cosgrove-a-steem-centric-discord-bot-framework)
* [How to Write a Discord Bot in Ruby](https://steemit.com/radiator/@inertia/how-to-write-a-discord-bot-in-ruby)

## Get in touch!

If you're using Cosgrove, I'd love to hear from you.  Drop me a line and tell me what you think!  I'm @inertia on STEEM and Discord.
  
## License

I don't believe in intellectual "property".  If you do, consider Cosgrove as licensed under a Creative Commons [![CC0](http://i.creativecommons.org/p/zero/1.0/80x15.png)](http://creativecommons.org/publicdomain/zero/1.0/) License.
