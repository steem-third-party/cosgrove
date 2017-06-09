# [Cosgrove](https://github.com/steem-third-party/cosgrove)
STEEM Centric Discord Bot Framework

## Features

* No features yet.  This is just the initial skeleton to get the continuous integrations started.  Stay tuned.

## Installation

```bash
$ gem install cosgrove
```

## Setup

Add a config file to your project called `config.yml`:

```yaml
:cosgrove:
  :secret: set this
:chain:
  :steem_account: 
  :steem_posting_wif: 
  :golos_account: 
  :golos_posting_wif: 
  :steem_api_url: https://steemd.steemit.com
  :golos_api_url: https://ws.golos.io
  :test_api_url: https://test.steem.ws
:discord:
  :log_mode: info
```

You should change the `secret` key using:

```ruby
SecureRandom.hex(32)
```

## Usage

Cosgrove is based on `discordrb`, see: https://github.com/meew0/discordrb

All features offered by `discordrb` are available in Cosgrove.  In addition, Cosgrove comes with pre-defined commands.

```ruby
require 'cosgrove'

bot = Cosgrove::Bot.new token: '<token here>', client_id: 168123456789123456

bot.message(with_text: 'Ping!') do |event|
  event.respond 'Pong!'
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

## Get in touch!

If you're using Cosgrove, I'd love to hear from you.  Drop me a line and tell me what you think!  I'm @inertia on STEEM and Discord.
  
## License

I don't believe in intellectual "property".  If you do, consider Cosgrove as licensed under a Creative Commons [![CC0](http://i.creativecommons.org/p/zero/1.0/80x15.png)](http://creativecommons.org/publicdomain/zero/1.0/) License.
