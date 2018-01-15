require 'test_helper'

class Cosgrove::UpvoteBotTest < Cosgrove::Test
  def setup
    @job = Cosgrove::UpvoteJob.new
  end
  
  def test_upvote_weight
    assert_equal 1000, @job.send(:upvote_weight)
  end
  
  def test_upvote_weight_by_channel_id
    assert_equal 10000, @job.send(:upvote_weight, 65442882692710)
    assert_equal 3333, @job.send(:upvote_weight, 92893087564620)
  end
  
  def test_perform_empty
    expected_result = 'Sorry, I wasn\'t paying attention.'
    
    @job.perform(mock_event, nil)
    result = mock_event.responses.last
    assert_equal expected_result, result
  end
  
  def test_perform_too_old
    slug = '@inertia/macintosh'
    expected_result = 'Unable to vote on that.  Too old.'
    
    VCR.use_cassette('upvote_job_perform_too_old', record: VCR_RECORD_MODE) do
      @job.perform(mock_event, slug)
      result = mock_event.responses.last
      skip if result =~ /Mongo is behind/
      assert_equal expected_result, result
    end
  end
  
  def test_perform_not_found
    slug = '@nobody/nothing'
    expected_result = 'Unable to find that.'
    
    VCR.use_cassette('upvote_job_perform_not_found', record: VCR_RECORD_MODE) do
      @job.perform(mock_event, slug)
      result = mock_event.responses.last
      assert result.include? expected_result
    end
  end
  
  def test_perform_nsfw
    slug = '@nobody/nothing'
    expected_result = 'Unable to vote on that.'
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
    
    VCR.use_cassette('upvote_job_perform_with_args', erb: erb, record: VCR_RECORD_MODE) do
      @job.perform(mock_event, slug)
      result = mock_event.responses.last
      assert_equal expected_result, result
    end
    
    erb[:parent_permlink] = 'nsfw'
    
    VCR.use_cassette('upvote_job_perform_with_args', erb: erb, record: VCR_RECORD_MODE) do
      @job.perform(mock_event, slug)
      result = mock_event.responses.last
      assert_equal expected_result, result
    end

    erb[:parent_permlink] = 'life'
    erb[:json_metadata] = '{\"tags\":[\"life\"]}'
    erb[:author_reputation] = -2260364491431

    VCR.use_cassette('upvote_job_perform_with_args', erb: erb, record: VCR_RECORD_MODE) do
      @job.perform(mock_event, slug)
      result = mock_event.responses.last
      assert_equal expected_result, result
    end
  end
  
  def test_disable_comment_voting_false_post
    slug = '@inertia/macintosh'
    expected_result = 'Unable to vote on that.  Too old.'
    
    VCR.use_cassette('upvote_job_perform_too_old', record: VCR_RECORD_MODE) do
      @job.perform(mock_event, slug)
      result = mock_event.responses.last
      skip if result =~ /Mongo is behind/
      assert_equal expected_result, result
    end
  end
  
  def test_disable_comment_voting_true_post
    slug = '@inertia/macintosh'
    expected_result = 'Unable to vote on that.  Too old.'
    mock_channel = MockChannel.new(id: 65442882692710)
    mock_event = MockEvent.new(bot: @bot, channel_id: mock_channel)
    
    VCR.use_cassette('upvote_job_perform_too_old', record: VCR_RECORD_MODE) do
      @job.perform(mock_event, slug)
      result = mock_event.responses.last
      skip if result =~ /Mongo is behind/
      assert_equal expected_result, result
    end
  end
end
