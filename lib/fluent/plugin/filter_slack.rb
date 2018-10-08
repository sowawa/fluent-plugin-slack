require 'fluent/plugin/filter_grep'

require_relative 'slack_client'
require_relative 'slack_common.rb'

module Fluent
  class SlackFilter < Fluent::Plugin::GrepFilter
    Fluent::Plugin.register_filter('slack', self)

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

    # for test
    attr_reader :slack, :time_format, :localtime, :timef, :mrkdwn_in, :post_message_opts

    def initialize
      super
      require 'uri'
    end

    SlackCommon.read_params(self)

    def configure(conf)
      conf['time_format'] ||= '%H:%M:%S' # old version compatiblity
      conf['localtime'] ||= true unless conf['utc']
      super
      init_config()
    end

    def filter(tag, time, record)

      unless super.nil?
        begin
          @slack.post_message(build_payloads(record, tag), @post_message_opts)
        rescue Timeout::Error => e
          log.warn "out_slack:", :error => e.to_s, :error_class => e.class.to_s
          raise e # let Fluentd retry
        rescue => e
          log.error "out_slack:", :error => e.to_s, :error_class => e.class.to_s
          log.warn_backtrace e.backtrace
          # discard. @todo: add more retriable errors
        end
      end

      record
    end

    private

    Field = Struct.new("Field", :title, :value)
    # ruby 1.9.x does not provide #to_h
    Field.send(:define_method, :to_h) { {title: title, value: value} }

    def build_payloads(record, tag)
      if @title
        build_title_payload_message(build_channel(record), { "tag" => Field.new(build_title(record), "#{build_message(record)}\n") })
      elsif @color
        build_color_payload_message(build_channel(record), "#{build_message(record)}\n")
      else
        build_plain_payload_message(build_channel(record), "#{build_message(record)}\n")
      end
    end

  end
end
