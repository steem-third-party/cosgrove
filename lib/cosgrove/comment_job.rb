require 'rdiscount'

module Cosgrove
  class CommentJob
    include Cosgrove::Utils
    include Cosgrove::Support
    
    def perform(event, slug, template, message = nil)
      author_name, permlink = parse_slug slug
      muted = muted by: steem_account, chain: :steem
      
      posts = SteemData::Post.root_posts.where(author: author_name, permlink: permlink)
      
      post = posts.first
      author = SteemData::Account.find_by(name: author_name)
      
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
      
      nope = if post.nil?
        "Sorry, couldn't find that."
      elsif cashout_time < Time.now.utc
        'Unable to comment on that.  Too old.'
      elsif post.parent_permlink == 'nsfw'
        puts "Won't comment because parent_permlink: nsfw"
        'Unable to comment on that.'
      elsif post.json_metadata.include?('nsfw')
        puts "Won't comment because json_metadata includes: nsfw"
        'Unable to comment on that.'
      elsif post.active_votes.map{ |v| v['voter'] }.include?('blacklist-a')
        puts "Won't comment blacklist-a voted."
        'Unable to comment on that.'
      elsif (rep = to_rep(post.author_reputation).to_f) < 25.0
        puts "Won't comment because rep too low: #{rep}"
        'Unable to comment on that.'
      elsif muted.include? author_name
        puts "Won't vote because author muted."
        'Unable to vote.'
      # elsif template == :welcome && author.post_count != 1
      #   'Sorry, this function is intended to welcome new authors.'
      elsif SteemData::Post.where(author: steem_account, parent_permlink: post.permlink).any?
        title = post.title
        title = post.permlink if title.empty?
        "I already commented on #{title} by #{post.author}."
      end

      if !!nope
        event.respond nope
        return
      end
      
      now = Time.now
      comment = {
        type: :comment,
        parent_permlink: post.permlink,
        author: steem_account,
        permlink: "re-#{post.author.gsub(/[^a-z0-9\-]+/, '-')}-#{post.permlink}-#{now.utc.strftime('%Y%m%dt%H%M%S%Lz')}", # e.g.: 20170225t235138025z
        title: '',
        body: merge(template, message, event.author.username),
        json_metadata: "{\"tags\":[\"#{post.parent_permlink}\"],\"app\":\"#{Cosgrove::AGENT_ID}\"}",
        parent_author: post.author
      }
      
      ap comment
      
      tx = new_tx :steem
      op = Radiator::Operation.new(comment)
      tx.operations << op
      
      response = tx.process(true)
      
      ap response.inspect
      
      if !!response.error
        'Unable to comment right now.  Maybe I already commented on that.  Try again later.'
      elsif !!response.result.id
        "Wrote #{template} comment on: #{post.title} by #{author_name}"
      else
        ':question:'
      end
    end
    
    def merge(template, message = nil, username = 'someone', markup = :html)
      @comment_md ||= "support/#{template}.md"
      @comment_body ||= {}
      @comment_body[template] ||= if File.exist?(@comment_md)
        File.read(@comment_md)
      end
      
      raise "Cannot read #{template} template or template is empty." unless @comment_body[template].present?
      
      merged = @comment_body[template]
      merged = merged.gsub('${message}', message) unless message.nil?
      merged = merged.gsub('${username}', username) unless username.nil?
      
      case markup
      when :html then RDiscount.new(merged).to_html
      when :markdown then merged
      end
    end
    
    def preview(template, event, message)
      m = "Your Message Here"
      discord_id = event.author.id
      
      @author = if (a = Cosgrove::Account.find_by_discord_id(discord_id)).nil?
        event.author.username
      else
        "@#{a.account_name}"
      end
      
      if message.present?
        @message = message
      end
      
      preview = []
      preview << "Set by **#{@author}**" if @author.present?
      preview << "```md\n"
      preview << merge(template, @message || m, @author, :markdown)
      preview << "\n```"
      
      preview.join('')
    end
  end
end
