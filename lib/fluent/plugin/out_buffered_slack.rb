module Fluent
  class BufferedSlackOutputError < StandardError; end
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
      begin
        payload = {
          channel:      @channel,
            username:   @username,
            icon_emoji: @icon_emoji,
            attachments: [{
              fallback: messages.keys.join(','),
              color:    @color,
              fields:   messages.map{|k,v| {title: k, value: v} }
            }]}
        post_request(
          payload: payload.to_json
        )
      rescue => e
        $log.error("Slack Error: #{e.backtrace[0]} / #{e.message}")
      end
    end

    def initialize
      super
      require 'active_support/time'
      require 'uri'
      require 'net/http'
    end

    def configure(conf)
      super
      @channel  = URI.unescape(conf['channel'])
      @username = conf['username'] || 'fluentd'
      @color    = conf['color'] || 'good'
      @icon_emoji = conf['icon_emoji'] || ':question:'
      @timezone   = conf['timezone'] || 'UTC'
      @team       = conf['team']
      @api_key    = conf['api_key']
    end

    private
    def endpoint
      URI.parse "https://#{@team}.slack.com/services/hooks/incoming-webhook?token=#{@api_key}"
    end

    def post_request(data)
      req = Net::HTTP::Post.new endpoint.request_uri
      req.set_form_data(data)
      http = Net::HTTP.new endpoint.host, endpoint.port
      http.use_ssl = (endpoint.scheme == "https")
      res = http.request(req)
      if res.code != "200"
        raise BufferedSlackOutputError, "Slack.com - #{res.code} - #{res.body}"
      end
    end
  end
end
