module Cosgrove
  class FindCommunitiesJob
    def perform(event, args, limit = 1000, chain = :steem)
      chain = chain.to_s.downcase.to_sym
      terms = args.map{|term| "%#{term.downcase.strip}%"}
      
      all_communities = case chain
      when :steem then SteemApi::Tx::Custom::Community.where('id >= 217640816').op('updateProps').order(id: :desc).limit(limit)
      when :hive then HiveSQL::Tx::Custom::Community.where('id >= 217640816').op('updateProps').order(id: :desc).limit(limit)
      end
      
      all_communities = all_communities.select("*, (SELECT [Accounts].[recovery_account] FROM [Accounts] WHERE [Accounts].[name] = JSON_VALUE([TxCustoms].[json_metadata], '$[1].community')) AS community_owner")
      
      communities = all_communities.all
      
      terms.each do |term|
        communities = communities.where("LOWER([TxCustoms].[json_metadata]) LIKE ? OR required_posting_auth LIKE ? OR (SELECT [Accounts].[recovery_account] FROM [Accounts] WHERE [Accounts].[name] = JSON_VALUE([TxCustoms].[json_metadata], '$[1].community')) = ?", term, term, term)
      end
      
      event.channel.start_typing if !!event
      
      if communities.none?
        msg = "Unable to find communities with: `#{args.join(' ')}`"
        
        guess_communities = all_communities.all
        
        terms.each do |term|
          pattern = term.chars.each.map{ |c| c }.join('%')
          pattern = pattern.gsub('%%', '%')
          guess_communities = guess_communities.where("LOWER(JSON_VALUE([TxCustoms].[json_metadata], '$[1].props.title')) LIKE ?", pattern)
        end
        
        if guess_communities.any? && !!(guess = guess_communities.sample.payload['props']['title'] rescue nil)
          msg += "\nDid you mean: #{guess}"
        end
        
        if !!event
          event << msg
        end
        
        return []
      end
      
      communities
    end
  end
end
