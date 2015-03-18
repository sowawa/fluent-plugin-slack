require_relative 'slack_client'

module Fluent
  class SlackOutput < Fluent::TimeSlicedOutput
    Fluent::Plugin.register_output('buffered_slack', self) # old version compatiblity
    Fluent::Plugin.register_output('slack', self)

    include SetTimeKeyMixin
    include SetTagKeyMixin

    config_set_default :include_time_key, true
    config_set_default :include_tag_key, true
   
    config_param :webhook_url,   :string, default: nil # incoming webhook
    config_param :token,         :string, default: nil # api token
    config_param :username,      :string, default: 'fluentd'
    config_param :color,         :string, default: 'good'
    config_param :icon_emoji,    :string, default: ':question:'

    config_param :channel,       :string
    config_param :channel_keys,  default: nil do |val|
      val.split(',')
    end
    config_param :title,         :string, default: nil
    config_param :title_keys,    default: nil do |val|
      val.split(',')
    end
    config_param :message,       :string, default: nil
    config_param :message_keys,  default: nil do |val|
      val.split(',')
    end

    # for test
    attr_reader :slack, :time_format

    def initialize
      super
      require 'uri'
    end

    def configure(conf)
      @time_format ||= conf['time_format'] ||= '%H:%M:%S' # old version compatiblity
 
      super

      @channel = URI.unescape(@channel) # old version compatibility
      @channel = '#' + @channel unless @channel.start_with?('#')

      if @webhook_url
        # following default values are for old version compatibility
        @title         ||= '%s'
        @title_keys    ||= %w[tag]
        @message       ||= '[%s] %s'
        @message_keys  ||= %w[time message]
        @slack = Fluent::SlackClient::IncomingWebhook.new(@webhook_url)
      else
        unless @token
          raise Fluent::ConfigError.new("`token` is required to call slack api")
        end
        @message      ||= '%s'
        @message_keys ||= %w[message]
        @slack = Fluent::SlackClient::WebApi.new
      end
      @slack.log = log
      @slack.debug_dev = log.out if log.level <= Fluent::Log::LEVEL_TRACE

      begin
        @message % (['1'] * @message_keys.length)
      rescue ArgumentError
        raise Fluent::ConfigError, "string specifier '%s' for `message`  and `message_keys` specification mismatch"
      end
      if @title and @title_keys
        begin
          @title % (['1'] * @title_keys.length)
        rescue ArgumentError
          raise Fluent::ConfigError, "string specifier '%s' for `title` and `title_keys` specification mismatch"
        end
      end
      if @channel_keys
        begin
          @channel % (['1'] * @channel_keys.length)
        rescue ArgumentError
          raise Fluent::ConfigError, "string specifier '%s' for `channel` and `channel_keys` specification mismatch"
        end
      end
    end

    def format(tag, time, record)
      [tag, time, record].to_msgpack
    end

    def write(chunk)
      begin
        payloads = build_payloads(chunk)
        payloads.each {|payload| @slack.post_message(payload) }
      rescue Net::OpenTimeout, Net::ReadTimeout => e
        log.warn "out_slack:", :error => e.to_s, :error_class => e.class.to_s
        raise e # let Fluentd retry
      rescue => e
        log.error "out_slack:", :error => e.to_s, :error_class => e.class.to_s
        log.warn_backtrace e.backtrace
        # discard. @todo: add more retriable errors
      end
    end

    private

    def build_payloads(chunk)
      if @title
        build_title_payloads(chunk)
      else
        build_plain_payloads(chunk)
      end
    end

    def common_payload
      return @common_payload if @common_payload
      @common_payload = {
        username:   @username,
        icon_emoji: @icon_emoji,
      }
      @common_payload[:token] = @token if @token
      @common_payload
    end

    Field = Struct.new("Field", :title, :value)

    def build_title_payloads(chunk)
      ch_fields = {}
      chunk.msgpack_each do |tag, time, record|
        channel = build_channel(record)
        per     = tag # title per tag
        ch_fields[channel]      ||= {}
        ch_fields[channel][per] ||= Field.new(build_title(record), '')
        ch_fields[channel][per].value << "#{build_message(record)}\n"
      end
      ch_fields.map do |channel, fields|
        {
          channel: channel,
          attachments: [{
            :color    => @color,
            :fallback => fields.values.map(&:title).join(' '), # fallback is the message shown on popup
            :fields   => fields.values.map(&:to_h)
          }],
        }.merge(common_payload)
      end
    end

    def build_plain_payloads(chunk)
      messages = {}
      chunk.msgpack_each do |tag, time, record|
        channel = build_channel(record)
        messages[channel] ||= ''
        messages[channel] << "#{build_message(record)}\n"
      end
      messages.map do |channel, text|
        {
          channel: channel,
          attachments: [{
            :color    => @color,
            :fallback => text,
            :text     => text,
          }],
        }.merge(common_payload)
      end
    end

    def build_message(record)
      values = fetch_keys(record, @message_keys)
      @message % values
    end

    def build_title(record)
      return @title unless @title_keys

      values = fetch_keys(record, @title_keys)
      @title % values
    end

    def build_channel(record)
      return @channel unless @channel_keys

      values = fetch_keys(record, @channel_keys)
      @channel % values
    end

    def fetch_keys(record, keys)
      Array(keys).map do |key|
        begin
          record.fetch(key).to_s
        rescue KeyError
          log.warn "out_slack: the specified key '#{key}' not found in record. [#{record}]"
          ''
        end
      end
    end
  end
end
