require_relative '../test_helper'
require 'fluent/plugin/out_slack'
require 'time'

class SlackOutputTest < Test::Unit::TestCase

  def setup
    super
    Fluent::Test.setup
  end

  CONFIG = %[
    channel channel
    token   XXX-XXX-XXX
    buffer_path tmp/
  ]

  def create_driver(conf = CONFIG)
    Fluent::Test::BufferedOutputTestDriver.new(Fluent::SlackOutput).configure(conf)
  end

  # old version compatibility with v0.4.0"
  def test_old_config
    # default check
    d = create_driver
    assert_equal true,         d.instance.localtime
    assert_equal 'fluentd',    d.instance.username
    assert_equal 'good',       d.instance.color
    assert_equal ':question:', d.instance.icon_emoji

    # incoming webhook endpoint was changed. api_key option should be ignored
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
      buffer_path tmp/
    ])
    assert_equal '#channel', d.instance.channel
    assert_equal '%Y/%m/%d %H:%M:%S', d.instance.time_format
    assert_equal 'username', d.instance.username
    assert_equal 'bad', d.instance.color
    assert_equal ':ghost:', d.instance.icon_emoji
    assert_equal 'XX-XX-XX', d.instance.token
    assert_equal '%s', d.instance.message
    assert_equal ['message'], d.instance.message_keys

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

  def test_default_incoming_webhook
    d = create_driver(%[
      channel channel
      webhook_url https://hooks.slack.com/services/XXX/XXX/XXX
      buffer_path tmp/
    ])
    time = Time.parse("2014-01-01 22:00:00 UTC").to_i
    d.tag  = 'test'
    mock(d.instance.slack).post_message(
      channel:     '#channel',
      username:    'fluentd',
      icon_emoji:  ':question:',
      attachments: [{
        color:    'good',
        fallback: 'test',
        fields:   [{
          title: 'test',
          value: "[07:00:00] sowawa1\n[07:00:00] sowawa2\n",
        }],
      }]
    )
    with_timezone('Asia/Tokyo') do
      d.emit({message: 'sowawa1'}, time)
      d.emit({message: 'sowawa2'}, time)
      d.run
    end
  end

  def test_default_slack_api
    d = create_driver(%[
      channel channel
      token   XX-XX-XX
      buffer_path tmp/
    ])
    time = Time.parse("2014-01-01 22:00:00 UTC").to_i
    d.tag  = 'test'
    mock(d.instance.slack).post_message(
      token:       'XX-XX-XX',
      channel:     '#channel',
      username:    'fluentd',
      icon_emoji:  ':question:',
      attachments: [{
        color:    'good',
        fallback: "sowawa1\nsowawa2\n",
        text:     "sowawa1\nsowawa2\n",
      }]
    )
    with_timezone('Asia/Tokyo') do
      d.emit({message: 'sowawa1'}, time)
      d.emit({message: 'sowawa2'}, time)
      d.run
    end
  end


  def test_title_keys
    d = create_driver(CONFIG + %[title %s\ntitle_keys tag])
    time = Time.parse("2014-01-01 22:00:00 UTC").to_i
    d.tag  = 'test'
    # attachments field should be changed to show the title
    mock(d.instance.slack).post_message(
      token:       'XXX-XXX-XXX',
      channel:     '#channel',
      username:    'fluentd',
      icon_emoji:  ':question:',
      attachments: [{
        color:    'good',
        fallback: d.tag,
        fields:   [
          {
            title: d.tag,
            value: "sowawa1\nsowawa2\n",
          }
        ]
      }]
    )
    with_timezone('Asia/Tokyo') do
      d.emit({message: 'sowawa1'}, time)
      d.emit({message: 'sowawa2'}, time)
      d.run
    end
  end

  def test_message_keys
    d = create_driver(CONFIG + %[message %s %s\nmessage_keys tag,message])
    time = Time.parse("2014-01-01 22:00:00 UTC").to_i
    d.tag  = 'test'
    mock(d.instance.slack).post_message(
      token:       'XXX-XXX-XXX',
      channel:     '#channel',
      username:    'fluentd',
      icon_emoji:  ':question:',
      attachments: [{
        color:    'good',
        fallback: "test sowawa1\ntest sowawa2\n",
        text:     "test sowawa1\ntest sowawa2\n",
      }]
    )
    with_timezone('Asia/Tokyo') do
      d.emit({message: 'sowawa1'}, time)
      d.emit({message: 'sowawa2'}, time)
      d.run
    end
  end

  def test_channel_keys
    d = create_driver(CONFIG + %[channel %s\nchannel_keys channel])
    time = Time.parse("2014-01-01 22:00:00 UTC").to_i
    d.tag  = 'test'
    mock(d.instance.slack).post_message(
      token:       'XXX-XXX-XXX',
      channel:     '#channel1',
      username:    'fluentd',
      icon_emoji:  ':question:',
      attachments: [{
        color:    'good',
        fallback: "sowawa1\n",
        text:     "sowawa1\n",
      }]
    )
    mock(d.instance.slack).post_message(
      token:       'XXX-XXX-XXX',
      channel:     '#channel2',
      username:    'fluentd',
      icon_emoji:  ':question:',
      attachments: [{
        color:    'good',
        fallback: "sowawa2\n",
        text:     "sowawa2\n",
      }]
    )
    with_timezone('Asia/Tokyo') do
      d.emit({message: 'sowawa1', channel: 'channel1'}, time)
      d.emit({message: 'sowawa2', channel: 'channel2'}, time)
      d.run
    end
  end
end
