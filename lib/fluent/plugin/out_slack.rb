require_relative 'slack_client'
require_relative 'slack_common.rb'

module Fluent
  class SlackOutput < Fluent::BufferedOutput
    Fluent::Plugin.register_output('buffered_slack', self) # old version compatiblity
    Fluent::Plugin.register_output('slack', self)

    # For fluentd v0.12.16 or earlier
    class << self
      unless method_defined?(:desc)
        def desc(description)
        end
      end
    end

    include SetTimeKeyMixin
    include SetTagKeyMixin
    include SlackCommon

    config_set_default :include_time_key, true
    config_set_default :include_tag_key, true

    SlackCommon.read_params(self)

    # for test
    attr_reader :slack, :time_format, :localtime, :timef, :mrkdwn_in, :post_message_opts

    def initialize
      super
      require 'uri'
    end

    def configure(conf)
      conf['time_format'] ||= '%H:%M:%S' # old version compatiblity
      conf['localtime'] ||= true unless conf['utc']
      super
      init_config()
    end

    def format(tag, time, record)
      [tag, time, record].to_msgpack
    end

    def write(chunk)
      begin
        payloads = build_payloads(chunk)
        payloads.each {|payload| @slack.post_message(payload, @post_message_opts) }
      rescue Timeout::Error => e
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
      elsif @color
        build_color_payloads(chunk)
      else
        build_plain_payloads(chunk)
      end
    end

    Field = Struct.new("Field", :title, :value)
    # ruby 1.9.x does not provide #to_h
    Field.send(:define_method, :to_h) { {title: title, value: value} }

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
        build_title_payload_message(channel, fields)
      end
    end

    def build_color_payloads(chunk)
      messages = {}
      chunk.msgpack_each do |tag, time, record|
        channel = build_channel(record)
        messages[channel] ||= ''
        messages[channel] << "#{build_message(record)}\n"
      end
      messages.map do |channel, text|
        build_color_payload_message(channel, text)
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
        build_plain_payload_message(channel, text)
      end
    end

  end
end
