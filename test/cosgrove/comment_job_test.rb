require 'test_helper'

class Cosgrove::CommentBotTest < Cosgrove::Test
  def setup
    bot = defined? @bot ? @bot : nil
    @job = Cosgrove::CommentJob.new
    @mock_event = MockEvent.new(bot: bot)
  end
  
  def test_perform_too_old
    slug = '@inertia/macintosh'
    expected_result = 'Unable to comment on that.  Too old.'
    
    VCR.use_cassette('comment_job_perform_too_old', record: VCR_RECORD_MODE) do
      @job.perform(@mock_event, slug, :welcome)
      result = @mock_event.responses.last
      skip if result =~ /Mongo is behind/
      assert_equal expected_result, result
    end
  end
  
  def test_perform_not_found
    slug = '@nobody/nothing'
    expected_result = 'Unable to find that.'
    
    VCR.use_cassette('comment_job_perform_not_found', record: VCR_RECORD_MODE) do
      @job.perform(@mock_event, slug, :welcome)
      result = @mock_event.responses.last
      assert result.include? expected_result
    end
  end
  
  def test_perform_nsfw
    slug = '@nobody/nothing'
    expected_result = 'Unable to comment on that.'
    erb = {
      author: 'nobody',
      permlink: 'nothing',
      parent_permlink: 'life',
      title: 'Untitled',
      json_metadata: '{\"tags\":[\"nsfw\"]}',
      author_reputation: 0,
      created: 15.minutes.ago.strftime('%Y-%m-%dT%H:%M:%S'),
      cashout_time: 7.days.from_now.strftime('%Y-%m-%dT%H:%M:%S')
    }
    
    skip 'Need to update test case.'
    
    VCR.use_cassette('comment_job_perform_with_args', erb: erb, record: VCR_RECORD_MODE) do
      @job.perform(@mock_event, slug, :welcome)
      result = @mock_event.responses.last
      assert_equal expected_result, result
    end
    
    erb[:parent_permlink] = 'nsfw'
    
    VCR.use_cassette('comment_job_perform_with_args', erb: erb, record: VCR_RECORD_MODE) do
      @job.perform(@mock_event, slug, :welcome)
      result = @mock_event.responses.last
      assert_equal expected_result, result
    end

    erb[:parent_permlink] = 'life'
    erb[:json_metadata] = '{\"tags\":[\"life\"]}'
    erb[:author_reputation] = -2260364491431

    VCR.use_cassette('comment_job_perform_with_args', erb: erb, record: VCR_RECORD_MODE) do
      @job.perform(@mock_event, slug, :welcome)
      result = @mock_event.responses.last
      assert_equal expected_result, result
    end
  end
end
