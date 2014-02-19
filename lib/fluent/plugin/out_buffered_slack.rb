module Fluent
  class BufferedSlackOutput < Fluent::TimeSlicedOutput
    Fluent::Plugin.register_output('buffered_slack', self)
    config_param :api_key,    :string
    config_param :team,       :string
    config_param :channel,    :string
    config_param :username,   :string
    config_param :color,      :string
    config_param :icon_emoji, :string
    config_param :timezone,   :string, default: nil

    attr_reader :slack

    def format(tag, time, record)
      [tag, time, record].to_msgpack
    end

    def write(chunk)
      messages = {}
      chunk.msgpack_each do |tag, time, record|
        messages[tag] = '' if messages[tag].nil?
        messages[tag] << "[#{Time.at(time).in_time_zone(@timezone)}] #{record['message']}\n"
      end
      messages.each do |tag, value|
        field = {
          title: tag,
          value: value
        }
        begin
          @slack.say(
            nil,
            { channel:     @channel,
              username:    @username,
              icon_emoji:  @icon_emoji,
              attachments: [{
                fallback: tag,
                color:    @color,
                fields:   [ field ]
              }]})
        rescue => e
            $log.error("Slack Error: #{e.backtrace[0]} / #{e.message}")
        end
      end
    end

    def initialize
      super
      require 'active_support/time'
      require 'slackr'
    end

    def configure(conf)
      super
      @slack    = Slackr::Webhook.new(conf['team'], conf['api_key'])
      @channel  = conf['channel']
      @username = conf['username'] || 'fluentd'
      @color    = conf['color'] || 'good'
      @icon_emoji = conf['icon_emoji'] || ':question:'
      @timezone = conf['timezone'] || 'UTC'
    end
  end
end
