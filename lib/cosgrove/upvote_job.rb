module Cosgrove
  class UpvoteJob
    include Cosgrove::Utils
    include Cosgrove::Support
    include Cosgrove::Config
    
    def initialize(options = {})
      @on_success = options[:on_success]
    end
    
    def perform(event, slug)
      if slug.nil? || slug.empty?
        event.respond 'Sorry, I wasn\'t paying attention.'
        return
      end
      
      author_name, permlink = parse_slug slug
      discord_id = event.author.id
      cb_account = Cosgrove::Account.find_by_discord_id(discord_id)
      registered = !!cb_account
      muted = muted by: steem_account, chain: :steem
      
      posts = SteemData::Post.root_posts.where(author: author_name, permlink: permlink)
      votes_today = SteemData::AccountOperation.type('vote').where(voter: steem_account).today
      today_count = votes_today.count
      author_count = votes_today.where(author: author_name).count
      vote_ratio = if today_count == 0
        0.0
      else
        author_count.to_f / today_count
      end
      
      post = posts.first
      
      if post.nil?
        # Fall back to RPC
        response = api(:steem).get_content(author_name, permlink)
        unless response.result.author.empty?
          post = response.result
          created = Time.parse(post.created + 'Z')
          cashout_time = Time.parse(post.cashout_time + 'Z')
        end
      end
      
      if post.nil?
        cannot_find_input(event)
        return
      end
      
      created ||= post.created
      cashout_time ||= post.cashout_time
      
      nope = if created > 5.minutes.ago
        "Give it a second!  It's going to SPACE!  Can you give it a second to come back from space?"
      elsif cashout_time < Time.now.utc
        'Unable to vote on that.  Too old.'
      elsif post.parent_permlink == 'nsfw'
        puts "Won't vote because parent_permlink: nsfw"
        'Unable to vote on that.'
      elsif post.json_metadata.include?('nsfw')
        puts "Won't vote because json_metadata includes: nsfw"
        'Unable to vote on that.'
      elsif post.active_votes.map{ |v| v['voter'] }.include?('blacklist-a')
        puts "Won't vote blacklist-a voted."
        'Unable to vote on that.'
      elsif (rep = to_rep(post.author_reputation).to_f) < 25.0
        puts "Won't vote because rep too low: #{rep}"
        'Unable to vote on that.'
      elsif muted.include? author_name
        puts "Won't vote because author muted."
        'Unable to vote.'
      elsif !registered
        'Unable to vote.  Feature resticted to registered users.'
      elsif cb_account.novote?
        'Unable to vote.  Your account has been resticted.'
      elsif today_count > 10 && vote_ratio > 0.1
        "Maybe later.  It seems like I've been voting for #{author_name} quite a bit lately."
      elsif post.active_votes.map{ |v| v['voter'] }.include?(steem_account)
        title = post.title
        title = post.permlink if title.empty?
        "I already voted on #{title} by #{post.author}."
      end

      if !!nope
        event.respond nope
        return
      end
      
      vote = {
        type: :vote,
        voter: steem_account,
        author: post.author,
        permlink: post.permlink,
        weight: upvote_weight(event.channel.id)
      }

      tx = new_tx :steem
      op = Radiator::Operation.new(vote)
      tx.operations << op
      response = tx.process(true)

      ap response.to_json

      if !!response.error
        'Unable to vote right now.  Maybe I already voted on that.  Try again later.'
      elsif !!response.result.id
        if created > 30.minutes.ago
          event.respond "*#{SteemSlap.slap(event.author.display_name)}*"
        end
        
        if !!@on_success
          begin
            @on_success.call(event, post.permlink)
          rescue => e
            ap e
          end
        end
        
        "Upvoted: #{post.title} by #{author_name}"
      else
        ':question:'
      end
    end
  private
    def upvote_weight(channel_id = nil)
      upvote_weight = cosgrove_upvote_weight
      
      case upvote_weight
      when 'dynamic'
        bot_account = find_account(steem_account)
        upvote_weight = bot_account.voting_power.to_i
      when 'upvote_rules'
        upvote_weight = channel_upvote_weight(channel_id)
        
        if upvote_weight == 'dynamic'
          bot_account = find_account(steem_account)
          upvote_weight = bot_account.voting_power.to_i
        else
          upvote_weight = (((upvote_weight || '100.0 %').to_f) * 100).to_i
        end
      else
        upvote_weight = (((upvote_weight || '100.0 %').to_f) * 100).to_i
      end
    end
  end
end
