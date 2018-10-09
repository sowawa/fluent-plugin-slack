require_relative '../test_helper'
require 'fluent/plugin/filter_slack'
require 'time'
require 'fluent/test/driver/filter'

class SlackFilterTest < Test::Unit::TestCase

  def setup
    super
    Fluent::Test.setup
    @icon_url = 'http://www.google.com/s2/favicons?domain=www.google.de'
  end

  CONFIG = %[
    channel channel
    webhook_url https://hooks.slack.com/services/XXXX/XXXX/XXX
  ]

  def default_payload
    {
      channel:    '#channel',
      mrkdwn:     true,
      link_names: true,
    }
  end

  def default_attachment
    {
      mrkdwn_in: %w[text fields],
    }
  end

  def create_driver(conf = CONFIG)
    Fluent::Test::Driver::Filter.new(Fluent::SlackFilter).configure(conf)
  end

  # old version compatibility with v0.4.0"
  def test_old_config
    # default check
    d = create_driver
    assert_equal true, d.instance.localtime
    assert_equal nil,  d.instance.username   # 'fluentd'    break lower version compatibility
    assert_equal nil,  d.instance.color      # 'good'       break lower version compatibility
    assert_equal nil,  d.instance.icon_emoji # ':question:' break lower version compatibility
    assert_equal nil,  d.instance.icon_url
    assert_equal true, d.instance.mrkdwn
    assert_equal true, d.instance.link_names
    assert_equal nil,  d.instance.parse

    assert_nothing_raised do
      create_driver(CONFIG + %[api_key testtoken])
    end

    # incoming webhook endpoint was changed. team option should be ignored
    assert_nothing_raised do
      create_driver(CONFIG + %[team sowasowa])
    end

    # rtm? it was not calling `rtm.start`. rtm option was removed and should be ignored
    assert_nothing_raised do
      create_driver(CONFIG + %[rtm true])
    end

    # channel should be URI.unescape-ed
    d = create_driver(CONFIG + %[channel %23test])
    assert_equal '#test', d.instance.channel

    # timezone should work
    d = create_driver(CONFIG + %[timezone Asia/Tokyo])
    assert_equal 'Asia/Tokyo', d.instance.timezone
  end

  def test_configure
    d = create_driver(%[
      channel      channel
      time_format  %Y/%m/%d %H:%M:%S
      username     username
      color        bad
      icon_emoji   :ghost:
      token        XX-XX-XX
      title        slack notice!
      message      %s
      message_keys message
    ])
    assert_equal '#channel', d.instance.channel
    assert_equal '%Y/%m/%d %H:%M:%S', d.instance.time_format
    assert_equal 'username', d.instance.username
    assert_equal 'bad', d.instance.color
    assert_equal ':ghost:', d.instance.icon_emoji
    assert_equal 'XX-XX-XX', d.instance.token
    assert_equal '%s', d.instance.message
    assert_equal ['message'], d.instance.message_keys

    # Allow DM
    d = create_driver(CONFIG + %[channel @test])
    assert_equal '@test', d.instance.channel

    assert_raise(Fluent::ConfigError) do
      create_driver(CONFIG + %[title %s %s\ntitle_keys foo])
    end

    assert_raise(Fluent::ConfigError) do
      create_driver(CONFIG + %[message %s %s\nmessage_keys foo])
    end

    assert_raise(Fluent::ConfigError) do
      create_driver(CONFIG + %[channel %s %s\nchannel_keys foo])
    end
  end

  def test_slack_configure
    # One of webhook_url or slackbot_url, or token is required
    assert_raise(Fluent::ConfigError) do
      create_driver(%[channel foo])
    end

    # webhook_url is an empty string
    assert_raise(Fluent::ConfigError) do
      create_driver(%[channel foo\nwebhook_url])
    end

    # webhook without channel (it works because webhook has a default channel)
    assert_nothing_raised do
      create_driver(%[webhook_url https://example.com/path/to/webhook])
    end

    # slackbot_url is an empty string
    assert_raise(Fluent::ConfigError) do
      create_driver(%[channel foo\nslackbot_url])
    end

    # slackbot without channel
    assert_raise(Fluent::ConfigError) do
      create_driver(%[slackbot_url https://example.com/path/to/slackbot])
    end

    # token is an empty string
    assert_raise(Fluent::ConfigError) do
      create_driver(%[channel foo\ntoken])
    end

    # slack webapi token without channel
    assert_raise(Fluent::ConfigError) do
      create_driver(%[token some_token])
    end
  end

  def test_timezone_configure
    time = Time.parse("2014-01-01 22:00:00 UTC").to_i

    d = create_driver(CONFIG + %[localtime])
    with_timezone('Asia/Tokyo') do
      assert_equal true,       d.instance.localtime
      assert_equal "07:00:00", d.instance.timef.format(time)
    end

    d = create_driver(CONFIG + %[utc])
    with_timezone('Asia/Tokyo') do
      assert_equal false,      d.instance.localtime
      assert_equal "22:00:00", d.instance.timef.format(time)
    end

    d = create_driver(CONFIG + %[timezone Asia/Taipei])
    with_timezone('Asia/Tokyo') do
      assert_equal "Asia/Taipei", d.instance.timezone
      assert_equal "06:00:00",    d.instance.timef.format(time)
    end
  end

  def test_time_format_configure
    time = Time.parse("2014-01-01 22:00:00 UTC").to_i

    d = create_driver(CONFIG + %[time_format %Y/%m/%d %H:%M:%S])
    with_timezone('Asia/Tokyo') do
      assert_equal "2014/01/02 07:00:00", d.instance.timef.format(time)
    end
  end

  def test_buffer_configure
    assert_nothing_raised do
      create_driver(CONFIG + %[buffer_type file\nbuffer_path tmp/])
    end
  end

  def test_icon_configure
    # default
    d = create_driver(CONFIG)
    assert_equal nil, d.instance.icon_emoji
    assert_equal nil, d.instance.icon_url

    # either of icon_emoji or icon_url can be specified
    assert_raise(Fluent::ConfigError) do
      d = create_driver(CONFIG + %[icon_emoji :ghost:\nicon_url #{@icon_url}])
    end

    # icon_emoji
    d = create_driver(CONFIG + %[icon_emoji :ghost:])
    assert_equal ':ghost:', d.instance.icon_emoji
    assert_equal nil, d.instance.icon_url

    # icon_url
    d = create_driver(CONFIG + %[icon_url #{@icon_url}])
    assert_equal nil, d.instance.icon_emoji
    assert_equal @icon_url, d.instance.icon_url
  end

  def test_link_names_configure
    # default
    d = create_driver(CONFIG)
    assert_equal true, d.instance.link_names

    # true
    d = create_driver(CONFIG + %[link_names true])
    assert_equal true, d.instance.link_names

    # false
    d = create_driver(CONFIG + %[link_names false])
    assert_equal false, d.instance.link_names
  end

  def test_parse_configure
    # default
    d = create_driver(CONFIG)
    assert_equal nil, d.instance.parse

    # none
    d = create_driver(CONFIG + %[parse none])
    assert_equal 'none', d.instance.parse

    # full
    d = create_driver(CONFIG + %[parse full])
    assert_equal 'full', d.instance.parse

    # invalid
    assert_raise(Fluent::ConfigError) do
      d = create_driver(CONFIG + %[parse invalid])
    end
  end

  def test_mrkwn_configure
    # default
    d = create_driver(CONFIG)
    assert_equal true, d.instance.mrkdwn
    assert_equal %w[text fields], d.instance.mrkdwn_in

    # true
    d = create_driver(CONFIG + %[mrkdwn true])
    assert_equal true, d.instance.mrkdwn
    assert_equal %w[text fields], d.instance.mrkdwn_in

    # false
    d = create_driver(CONFIG + %[mrkdwn false])
    assert_equal false, d.instance.mrkdwn
    assert_equal nil, d.instance.mrkdwn_in
  end

  def test_https_proxy_configure
    # default
    d = create_driver(CONFIG)
    assert_equal nil, d.instance.slack.https_proxy
    assert_equal Net::HTTP, d.instance.slack.proxy_class

    # https_proxy
    d = create_driver(CONFIG + %[https_proxy https://proxy.foo.bar:443])
    assert_equal URI.parse('https://proxy.foo.bar:443'), d.instance.slack.https_proxy
    assert_not_equal Net::HTTP, d.instance.slack.proxy_class # Net::HTTP.Proxy
  end

  def test_auto_channels_create_configure
    # default
    d = create_driver(CONFIG)
    assert_equal false, d.instance.auto_channels_create
    assert_equal({}, d.instance.post_message_opts)

    # require `token`
    assert_raise(Fluent::ConfigError) do
      d = create_driver(CONFIG + %[auto_channels_create true])
    end

    # auto_channels_create
    d = create_driver(CONFIG + %[auto_channels_create true\ntoken XXX-XX-XXX])
    assert_equal true, d.instance.auto_channels_create
    assert_equal({auto_channels_create: true}, d.instance.post_message_opts)
  end

  #Can't figure out how to adapt those "mock" tests...

end
