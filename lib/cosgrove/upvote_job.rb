module Cosgrove
  class UpvoteJob
    include Utils
    include Support
    include Config
    
    def initialize(options = {})
      @on_success = options[:on_success]
    end
    
    def perform(event, slug, chain = :hive)
      if slug.nil? || slug.empty?
        event.respond 'Sorry, I wasn\'t paying attention.'
        return
      end
      
      chain = chain.to_s.downcase.to_sym
      author_name, permlink = parse_slug slug
      discord_id = event.author.id
      cb_account = Cosgrove::Account.find_by_discord_id(discord_id)
      registered = !!cb_account
      muters = cosgrove_operators
      muters << hive_account
      muted = muted by: muters, chain: :steem
      
      post = find_comment(chain: chain, author_name: author_name, permlink: permlink)
      
      if post.nil?
        cannot_find_input(event)
        return
      end
      
      votes_today = case chain
      # when :steem then SteemApi::Tx::Vote.where(voter: steem_account).today
      when :hive then HiveSQL::Tx::Vote.where(voter: hive_account).today
      end
      today_count = votes_today.count
      author_count = votes_today.where(author: author_name).count
      vote_ratio = if today_count == 0
        0.0
      else
        author_count.to_f / today_count
      end
      
      created ||= post.created
      cashout_time ||= post.cashout_time
      root_post = post.parent_author == ''
      
      if created.class == String
        created = Time.parse(created + 'Z')
        cashout_time = Time.parse(cashout_time + 'Z')
      end
      
      active_votes = if post.active_votes.class == String
        active_votes = JSON[post.active_votes]
      else
        post.active_votes
      end
      
      nope = if created > 1.minute.ago
        "Give it a second!  It's going to SPACE!  Can you give it a second to come back from space?"
      elsif created > 20.minutes.ago
        "Unable to vote.  Please wait 20 minutes before voting."
      elsif cashout_time < Time.now.utc
        'Unable to vote on that.  Too old.'
      elsif post.parent_permlink == 'nsfw'
        puts "Won't vote because parent_permlink: nsfw"
        'Unable to vote on that.'
      elsif post.json_metadata.include?('nsfw')
        puts "Won't vote because json_metadata includes: nsfw"
        'Unable to vote on that.'
      elsif active_votes.map{ |v| v['voter'] }.include?('blacklist-a')
        puts "Won't vote blacklist-a voted."
        'Unable to vote on that.'
      elsif (rep = to_rep(post.author_reputation).to_f) < 25.0
        puts "Won't vote because rep too low: #{rep}"
        'Unable to vote on that.'
      elsif muted.include? author_name
        puts "Won't vote because author muted."
        'Unable to vote because the author has been muted by the operators.'
      elsif !root_post && channel_disable_comment_voting(event.channel.id)
        puts "Won't vote because comment voting is disabled."
        'Unable to vote.'
      elsif !registered
        'Unable to vote.  Feature resticted to registered users.'
      elsif cb_account.novote?
        'Unable to vote.  Your account has been resticted.'
      elsif today_count > 10 && vote_ratio > 0.1
        "Maybe later.  It seems like I've been voting for #{author_name} quite a bit lately."
      elsif active_votes.map{ |v| v['voter'] }.include?(hive_account)
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
        voter: hive_account,
        author: post.author,
        permlink: post.permlink,
        weight: upvote_weight(event.channel.id)
      }

      tx = new_tx :steem
      tx.operations << vote
      friendy_error = nil
      response = nil
      
      loop do
        begin
          response = tx.process(true)
        rescue => e
          puts "Unable to vote: #{e}"
          ap e
        end
        
        if !!response && !!response.error
          message = response.error.message
          if message.to_s =~ /missing required posting authority/
            friendy_error = "Failed: Check posting key."
            break
          elsif message.to_s =~ /You have already voted in a similar way./
            friendy_error = "Failed: duplicate vote."
            break
          elsif message.to_s =~ /Can only vote once every 3 seconds./
            puts "Retrying: voting too quickly."
            sleep 3
            redo
          elsif message.to_s =~ /Voting weight is too small, please accumulate more voting power or steem power./
            friendy_error = "Failed: voting weight too small"
            break
          elsif message.to_s =~ /unknown key/
            friendy_error = "Failed: unknown key (testing?)"
            break
          elsif message.to_s =~ /tapos_block_summary/
            puts "Retrying vote/comment: tapos_block_summary (?)"
            redo
          elsif message.to_s =~ /now < trx.expiration/
            puts "Retrying vote/comment: now < trx.expiration (?)"
            redo
          elsif message.to_s =~ /signature is not canonical/
            puts "Retrying vote/comment: signature was not canonical (bug in Radiator?)"
            redo
          elsif message.to_s =~ /STEEMIT_UPVOTE_LOCKOUT_HF17/
            friendy_error = "Failed: upvote lockout (last twelve hours before payout)"
            break
          else
            friendy_error = 'Unable to vote right now.  Maybe I already voted on that.  Try again later.'
            ap response.error
            break
          end
        end
        
        break
      end

      if !!friendy_error
        friendy_error
      elsif !!response.result.id
        ap response.to_json

        if !!@on_success
          begin
            @on_success.call(event, "@#{post.author}/#{post.permlink}")
          rescue => e
            ap e
            ap e.backtrace
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
        bot_account = find_account(hive_account)
        upvote_weight = bot_account.voting_power.to_i
      when 'upvote_rules'
        upvote_weight = channel_upvote_weight(channel_id)
        
        if upvote_weight == 'dynamic'
          bot_account = find_account(hive_account)
          upvote_weight = bot_account.voting_power.to_i
        else
          upvote_weight = (((upvote_weight || '0.00 %').to_f) * 100).to_i
        end
      else
        upvote_weight = (((upvote_weight || '0.0 %').to_f) * 100).to_i
      end
    end
  end
end
