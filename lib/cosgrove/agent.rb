require 'mechanize'

module Cosgrove
  class Agent < Mechanize
    COOKIE_FILE ||= 'cookies.yml'
    
    def initialize
      super('cosgrove')
      
      @agent.user_agent = 'Mozilla/5.0 (iPad; U; CPU OS 3_2_1 like Mac OS X; en-us) AppleWebKit/531.21.10 (KHTML, like Gecko) Mobile/7B405'
      @agent.keep_alive = false
      @agent.open_timeout = 10
      @agent.read_timeout = 10
      
      # Cookie management, see: https://gist.github.com/makevoid/4282237
      @agent.pre_connect_hooks << Proc.new do 
        @agent.cookie_jar.load COOKIE_FILE if ::File.exist?(COOKIE_FILE)
      end
      
      @agent.post_connect_hooks << Proc.new do
        @agent.cookie_jar.save COOKIE_FILE
      end
    end
  end
end
