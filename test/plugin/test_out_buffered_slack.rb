require 'test_helper'
require 'time'

class BufferedSlackOutputTest < Test::Unit::TestCase

  def setup
    super
    Fluent::Test.setup
  end

  CONFIG = %[
    type buffered_slack
    api_key testtoken
    team    sowasowa
    channel  %23test
    username testuser
    color    good
    icon_emoji :ghost:
    timezone Asia/Tokyo
    compress gz
    buffer_path ./test/tmp
    utc
  ]

  def create_driver(conf = CONFIG)
    Fluent::Test::BufferedOutputTestDriver.new(Fluent::BufferedSlackOutput).configure(conf)
  end

  def test_format
    d = create_driver
    time = Time.parse("2014-01-01 22:00:00 UTC").to_i
    d.tag = 'test'
    stub(d.instance.slack).ping(
      nil,
      channel:    '%23test',
      username:   'testuser',
      icon_emoji: ':ghost:',
      attachments: [{
        fallback: d.tag,
        color:    'good',
        fields:   [
          {
            title: d.tag,
            value: "[#{Time.at(time).in_time_zone('Tokyo')}] sowawa\n"
          }]}])
    d.emit({message: 'sowawa'}, time)
    d.expect_format %[#{['test', time, {message: 'sowawa'}].to_msgpack}]
    d.run
  end

  def test_write
    d = create_driver
    time = Time.parse("2014-01-01 22:00:00 UTC").to_i
    d.tag  = 'test'
    stub(d.instance.slack).ping(
      nil,
      channel:    '%23test',
      username:   'testuser',
      icon_emoji: ':ghost:',
      attachments: [{
        fallback: d.tag,
        color:    'good',
        fields:   [
          {
            title: d.tag,
            value: "[#{Time.at(time).in_time_zone('Tokyo')}] sowawa1\n" +
                     "[#{Time.at(time).in_time_zone('Tokyo')}] sowawa2\n"
          }]}])
    d.emit({message: 'sowawa1'}, time)
    d.emit({message: 'sowawa2'}, time)
    d.run
  end
end
