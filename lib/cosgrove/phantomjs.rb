require 'phantomjs'

# See: http://www.thegreatcodeadventure.com/screen-capture-in-rails-with-phantomjs/
module Cosgrove
  module Phantomjs
    PATH_TO_PHANTOM_SCRIPT = "#{File.dirname(__FILE__)}/../../support/js/screencap.js"
    
    def take_screencap(url, filename = nil, width = 64, height = 64)
      target_path = Digest::MD5.hexdigest(filename || url.parameterize)
      target_path += '.png'
      
      Dir.chdir('/tmp')
      system "phantomjs #{PATH_TO_PHANTOM_SCRIPT} \"#{url}\" #{target_path} #{width} #{height}"
      
      File.open(target_path)
    end
  end
end
