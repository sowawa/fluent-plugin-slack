require 'test_helper'
require 'time'

class BufferedSlackOutputTest < Test::Unit::TestCase

  def setup
    super
    Fluent::Test.setup
  end

  CONFIG2 = %[
    type buffered_slack
    rtm true
    token testtoken
    channel C01234567
    username testuser
    color good
    icon_emoji :ghost:
    buffer_path ./test/tmp
  ]

  def create_driver(conf = CONFIG2)
    Fluent::Test::BufferedOutputTestDriver.new(Fluent::BufferedSlackOutput).configure(conf)
  end

  def test_format_rtm
    d = create_driver
    time = Time.parse("2014-01-01 22:00:00 UTC").to_i
    d.tag = 'test'
    stub(d.instance.slack).ping(
      nil,
      channel:    'C01234567',
      username:   'testuser',
      icon_emoji: ':ghost:',
      attachments: [{
        color:    'good',
        text: "[#{Time.at(time).in_time_zone('Tokyo')}] sowawa\n"
      }]
    )
    d.emit({message: 'sowawa'}, time)
    d.expect_format %[#{['test', time, {message: 'sowawa'}].to_msgpack}]
    d.run
  end

  def test_write_rtm
    d = create_driver
    time = Time.parse("2014-01-01 22:00:00 UTC").to_i
    d.tag  = 'test'
    stub(d.instance.slack).ping(
      nil,
      channel:    'C01234567',
      username:   'testuser',
      icon_emoji: ':ghost:',
      attachments: [{
        color:    'good',
        text: "[#{Time.at(time).in_time_zone('Tokyo')}] sowawa\n"
      }]
    )
    d.emit({message: 'sowawa1'}, time)
    d.emit({message: 'sowawa2'}, time)
    d.run
  end
end
