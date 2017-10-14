require 'discordrb'

module Cosgrove
  require 'cosgrove/snark_commands'
  
  cattr_accessor :latest_steemit_link, :latest_golos_link
  
  @@latest_steemit_link = {}
  @@latest_golosio_link = {}
  
  class Bot < Discordrb::Commands::CommandBot
    include Support
    include SnarkCommands
    
    def initialize(options = {})
      options[:token] ||= cosgrove_token
      options[:client_id] ||= cosgrove_client_id
      super(options)
      
      @on_success_upvote_job = options[:on_success_upvote_job]
      @on_success_register_job = options[:on_success_register_job]
      
      self.bucket :voting, limit: 4, time_span: 8640, delay: 10

      add_all_commands
      add_all_messages
      SnarkCommands::add_all_snark_commands(self)
    end
    
    def add_all_messages
      # A user typed a link to steemit.com
      self.message(content: /http[s]*:\/\/steemit\.com\/.*/, ignore_bots: false) do |event|
        link = event.content.split(' ').first
        Cosgrove::latest_steemit_link[event.channel.name] = link
        append_link_details(event, link)
      end

      # A user typed a link to golos.io.
      self.message(content: /http[s]*:\/\/golos\.io\/.*/, ignore_bots: false) do |event|
        link = event.content.split(' ').first
        Cosgrove::latest_golosio_link[event.channel.name] = link
      end
    end
    
    def add_all_commands
      self.command :help do |_event, *args|
        help = []
        help << "`$slap [target]` - does a slap on the `target`"
        help << "`$verify <account> [chain]` - check `account` association with Discord users (`chain` default `steem`)"
        help << "`$register <account> [chain]` - associate `account` with your Discord user (`chain` default `steem`)"
        help << "`$upvote [url]` - upvote from #{steem_account}; empty or `^` to upvote last steemit link"
        help.join("\n")
      end
      
      self.command :version do |_|
        "cosgrove: #{Cosgrove::VERSION} :: https://github.com/steem-third-party/cosgrove"
      end
      
      self.command :verify do |event, key, chain = :steem|
        return if event.channel.pm? && !allow_pm_commands
        
        mongo_behind_warning(event)
        if key.nil?
          event.respond "To create an account: https://steemit.com/enter_email?r=#{steem_account}"
          return
        end
        
        account = find_account(key, event)
        
        if !!account && account.respond_to?(:name)
          cb_account = Cosgrove::Account.new(account.name, chain)
        else
          discord_id = key.split('@').last.split('>').first.to_i
          cb_account = Cosgrove::Account.find_by_discord_id(discord_id, chain)
          
          account = if !!cb_account
            find_account(cb_account.account_name, event)
          end
        end
        
        if !!account && !!cb_account && cb_account.discord_ids.any?
          if cb_account.hidden?
            "#{chain.to_s.upcase} account `#{account.name}` has been registered."
          else
            discord_ids = cb_account.discord_ids.map { |id| "<@#{id}>" }
            
            "#{chain.to_s.upcase} account `#{account.name}` has been registered with #{discord_ids.to_sentence}."
          end
        elsif !!account
          "#{chain.to_s.upcase} account `#{account.name}` has not been registered with any Discord account.  To register:\n`$register #{account.name}`"
        elsif discord_id.to_i > 0
          "<@#{discord_id}> has not been associated with a #{chain.to_s.upcase} account.  To register:\n`$register <account>`"
        else
          "No association found.  To register:\n`$register <account>`"
        end
      end
      
      self.command :register do |event, account_name, chain = :steem|
        return if event.channel.pm? && !allow_pm_commands
        
        mongo_behind_warning(event)
        account = find_account(account_name, event)
        discord_id = event.author.id
        
        return nil unless !!account
        
        cb_account = Cosgrove::Account.new(account.name, chain)
        
        if cb_account.discord_ids.include? discord_id
          event.respond "Already registered `#{account.name}` on `#{chain.upcase}` with <@#{discord_id}>"
          return
        end
        
        memo_key = cb_account.memo_key(discord_id)
        op = SteemData::AccountOperation.type('transfer').
          where(account: steem_account, from: account.name, to: steem_account, memo: {'$regex' => ".*#{memo_key}.*"}).last
          
        if op.nil?
          # Fall back to RPC.  The transaction is so new, SteemData hasn't seen it
          # yet, SteemData is behind, or there is no such transfer.
          
          response = api(chain).get_account_history(steem_account, -1000, 1000)
          op = response.result.map do |history|
            e = history.last.op
            type = e.first
            next unless type == 'transfer'
            o = e.last
            next unless o.from == account.name
            next unless o.to == steem_account
            next unless o.memo =~ /.*#{memo_key}.*/
            
            o
          end.compact.last
        end
          
        if !!op
          cb_account.add_discord_id(discord_id)
          
          if !!@on_success_register_job
            begin
              @on_success_register_job.call(event, cb_account)
            rescue => e
              ap e
              ap e.backtrace
            end
          end
          
          "Ok.  #{chain.to_s.upcase} account #{account.name} has been registered with <@#{discord_id}>."
        else
          "To register `#{account.name}` with <@#{discord_id}>, send `0.001 #{chain_asset}' or '0.001 #{debt_asset}` to `#{steem_account}` with memo: `#{memo_key}`\n\nThen type `$register #{account.name}` again."
        end
      end
      
      self.command(:upvote, bucket: :voting, rate_limit_message: 'Sorry, you are in cool-down.  Please wait %time% more seconds.') do |event, slug = nil|
        return if event.channel.pm? && !allow_pm_commands
        
        slug = Cosgrove::latest_steemit_link[event.channel.name] if slug.nil? || slug.empty? || slug == '^'
        options = {
          on_success: @on_success_upvote_job
        }

        Cosgrove::UpvoteJob.new(options).perform(event, slug)
      end
    end
  end
end
