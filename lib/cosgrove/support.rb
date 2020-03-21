module Cosgrove
  module Support
    include Utils
    include ActionView::Helpers::TextHelper
    include ActionView::Helpers::DateHelper
    
    def suggest_account_name(account_name, chain = :steem)
      chain = chain.to_s.downcase.to_sym
      pattern = account_name.chars.each.map{ |c| c }.join('%')
      guesses = case chain
      when :steem then SteemApi::Account.where("name LIKE '%#{pattern}%'").pluck(:name)
      when :hive then HiveSQL::Account.where("name LIKE '%#{pattern}%'").pluck(:name)
      else
        []
      end
      
      if guesses.any?
        guesses.sample
      end
    end

    def unknown_account(account_name, event = nil)
      help = ["Unknown account: *#{account_name}*"]
      event.channel.start_typing if !!event
      guess = suggest_account_name(account_name)

      help << ", did you mean: #{guess}?" if !!guess
      
      if !!event
        event.respond help.join
        return
      end
      
      help.join
    end
    
    def cannot_find_input(event, message_prefix = "Unable to find that.")
      message = [message_prefix]
      
      event.respond message.join(' ')
    end
    
    def append_link_details(event, slug)
      return if skipped_channel? event.channel.id
      
      chain = :steem
      author_name, permlink = parse_slug slug
      created = nil
      cashout_time = nil
      message = nil
      
      return unless !!author_name && !!permlink
      
      if !!event
        begin
          message = event.respond "Looking up `#{author_name}/#{permlink}` ..."
        rescue Discordrb::Errors::NoPermission => _
          puts "Unable to append link details on #{event.channel.server.name} in #{event.channel.name}"
          skip_channel event.channel.id
          return nil
        end
      end
      
      posts = case chain
      when :steem then SteemApi::Comment.where(author: author_name, permlink: permlink)
      when :hive then HiveSQL::Comment.where(author: author_name, permlink: permlink)
      end
      
      posts.select(:ID, :created, :cashout_time, :author, :permlink, :active_votes, :children, :category)
      
      post = posts.last
      
      if post.nil?
        # Fall back to RPC
        api(chain).get_content(author_name, permlink) do |content, errors|
          unless content.author.empty?
            post = content
            created = Time.parse(content.created + 'Z')
            cashout_time = Time.parse(content.cashout_time + 'Z')
          end
        end
      end
      
      if post.nil?
        if !!message
          message = message.edit 'Looking for content on Hive ...'
        end
        
        # Fall back to Hive RPC
        api(:hive).get_content(author_name, permlink) do |content, errors|
          unless content.author.empty?
            post = content
            created = Time.parse(content.created + 'Z')
            cashout_time = Time.parse(content.cashout_time + 'Z')
          end
        end
      end
      
      if post.nil?
        if !!message
          message = message.edit 'Unable to locate.'
          sleep 5
          message.delete
        end
        
        return
      end
      
      created ||= post.created
      cashout_time ||= post.cashout_time
      
      details = []
      age = time_ago_in_words(created)
      age = age.slice(0, 1).capitalize + age.slice(1..-1)
      
      details << if created < 15.minutes.ago
        "#{age} old"
      else
        "**#{age}** old"
      end
      message = message.edit details.join('; ') if !!message
      
      if !!post.category && !!post.category.starts_with?('hive-') && (communities = Cosgrove::FindCommunitiesJob.new.perform(nil, [post.category]), 1).any?
        details << "in #{communities.first.payload['props']['title']}" rescue nil
        message = message.edit details.join('; ') if !!message
      end
      
      active_votes = case post.active_votes
      when String then JSON[post.active_votes] rescue []
      else; active_votes
      end
      
      if active_votes.respond_to?(:any?) && active_votes.any?
        upvotes = active_votes.map{ |v| v if v['weight'].to_i > 0 }.compact.count
        downvotes = active_votes.map{ |v| v if v['weight'].to_i < 0 }.compact.count
        netvotes = upvotes - downvotes
        details << "Net votes: #{netvotes}"
        message = message.edit details.join('; ') if !!message
        
        # Only append this detail of the post less than an hour old.
        if created > 1.hour.ago
          votes = case chain
          when :steem then SteemApi::Tx::Vote.where('timestamp > ?', post.created)
          when :hive then HiveSQL::Tx::Vote.where('timestamp > ?', post.created)
          end
          total_votes = votes.distinct("concat(author, permlink)").count
          total_voters = votes.distinct(:voter).count
            
          if total_votes > 0 && total_voters > 0
            details << "Out of #{pluralize(total_votes - netvotes, 'vote')} cast by #{pluralize(total_voters, 'voter')}"
            message = message.edit details.join('; ') if !!message
          end
        end
      end
      
      details << "Comments: #{post.children.to_i}"
      message = message.edit details.join('; ') if !!message
      
      # Page View counter is no longer supported by steemit.com.
      # page_views = page_views("/#{post.parent_permlink}/@#{post.author}/#{post.permlink}")
      # details << "Views: #{page_views}" if !!page_views
      # message = message.edit details.join('; ') if !!message
      
      details.join('; ') if event.nil?
    end
    
    def find_account(key, event = nil, chain = :steem)
      key = key.to_s.downcase
      chain ||= :steem
      chain = chain.to_s.downcase.to_sym
      
      
      case chain
      when :steem
        account = if (accounts = SteemApi::Account.where(name: key)).any?
          accounts.first
        end
      when :hive
        account = if (accounts = HiveSQL::Account.where(name: key)).any?
          accounts.first
        end
      end
      
      if account.nil?
        account = if !!(cb_account = Cosgrove::Account.find_by_discord_id(key, chain))
          cb_account.chain_account
        end
      end
      
      if account.nil?
        account = if !!key
          if chain == :steem && (accounts = SteemApi::Account.where(name: key)).any?
            accounts.first
          elsif chain == :hive && (accounts = HiveSQL::Account.where(name: key)).any?
            accounts.first
          else
            # Fall back to RPC
            api(chain).get_accounts([key]) do |_accounts, errors|
              _accounts.first
            end
          end
        end
      end
        
      if account.nil?
        unknown_account(key, event)
      else
        account
      end
    end
    
    def page_views(uri)
      begin
        @agent ||= Cosgrove::Agent.new
        page = @agent.get("https://steemit.com#{uri}")
        
        _uri = URI.parse('https://steemit.com/api/v1/page_view')
        https = Net::HTTP.new(_uri.host,_uri.port)
        https.use_ssl = true
        request = Net::HTTP::Post.new(_uri.path)
        request.initialize_http_header({
          'Cookie' => @agent.cookies.join('; '),
          'accept' => 'application/json',
          'Accept-Encoding' => 'gzip, deflate, br',
          'Accept-Language' => 'en-US,en;q=0.8',
          'Connection' => 'keep-alive',
          'content-type' => 'text/plain;charset=UTF-8',
          'Host' => 'steemit.com',
          'Origin' => 'https://steemit.com'
        })
        
        csrf = page.parser.to_html.split(':{"csrf":"').last.split('","new_visit":').first
        # Uncomment in case views stop showing.
        # puts "DEBUG: #{csrf}"
        return unless csrf.size == 36
        
        post_data = {
          csrf: csrf,
          page: uri
        }
        request.set_form_data(post_data)
        response = https.request(request)
        JSON[response.body]['views']
      rescue => e
        puts "Attempting to get page_view failed: #{e}"
      end
    end
    
    def last_irreversible_block(chain = :steem)
      chain ||= :steem
      chain = chain.to_s.downcase.to_sym
      seconds_ago = (head_block_number(chain) - last_irreversible_block_num(chain)) * 3
      
      "Last Irreversible Block was #{time_ago_in_words(seconds_ago.seconds.ago)} ago."
    end
    
    def send_url(event, url)
      open(url) do |f|
        tempfile = Tempfile.new(['send_url', ".#{url.split('.').last}"])
        tempfile.binmode
        tempfile.write(f.read)
        tempfile.close
        event.send_file File.open tempfile.path
      end
    end
    
    def muted(options = {})
      [] if options.empty?
      by = [options[:by]].flatten
      chain = options[:chain] || :steem
      chain = chain.to_s.downcase.to_sym
      muted = []
      
      by.each do |a|
        ignoring = []
        count = -1
        until count == ignoring.size
          count = ignoring.size
          follow_api(chain).get_following(a, ignoring.last, 'ignore', 100) do |ignores, errors|
            next unless defined? ignores.following
            
            ignoring += ignores.map(&:following)
            ignoring = ignoring.uniq
          end
        end
        muted += ignoring
      end
      
      muted.uniq
    end
    
    def skipped_channels
      @@skipped_channels ||= []
    end
    
    def skipped_channel?(id)
      skipped_channels.include? id
    end
    
    def skip_channel(id)
      skipped_channels << id
    end
  end
end
