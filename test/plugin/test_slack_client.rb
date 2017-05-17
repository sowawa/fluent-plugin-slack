require_relative '../test_helper'
require 'fluent/plugin/slack_client'
require 'time'
require 'dotenv'
require 'webrick'
require 'webrick/httpproxy'

# HOW TO RUN
#
# Create .env file with contents as:
#
#     WEBHOOK_URL=https://hooks.slack.com/services/XXXX/YYYY/ZZZZ
#     SLACKBOt_URL=https://xxxx.slack.com/services/hooks/slackbot?token=XXXX
#     SLACK_API_TOKEN=XXXXX
#
Dotenv.load
if ENV['WEBHOOK_URL'] and ENV['SLACKBOT_URL'] and ENV['SLACK_API_TOKEN']

  class TestProxyServer
    def initialize
      @proxy = WEBrick::HTTPProxyServer.new(
        :BindAddress => '127.0.0.1',
        :Port => unused_port,
      )
    end

    def proxy_url
      "https://127.0.0.1:#{unused_port}"
    end

    def start
      @thread = Thread.new do
        @proxy.start
      end
    end

    def shutdown
      @proxy.shutdown
    end

    def unused_port
      return @unused_port if @unused_port
      s = TCPServer.open(0)
      port = s.addr[1]
      s.close
      @unused_port = port
    end
  end

  class SlackClientTest < Test::Unit::TestCase
    class << self
      attr_reader :proxy

      def startup
        @proxy = TestProxyServer.new.tap {|proxy| proxy.start }
      end

      def shutdown
        @proxy.shutdown
      end
    end

    def setup
      super
      @incoming       = Fluent::SlackClient::IncomingWebhook.new(ENV['WEBHOOK_URL'])
      @slackbot       = Fluent::SlackClient::Slackbot.new(ENV['SLACKBOT_URL'])
      @api            = Fluent::SlackClient::WebApi.new

      proxy_url       = self.class.proxy.proxy_url
      @incoming_proxy = Fluent::SlackClient::IncomingWebhook.new(ENV['WEBHOOK_URL'], proxy_url)
      @slackbot_proxy = Fluent::SlackClient::Slackbot.new(ENV['SLACKBOT_URL'], proxy_url)
      @api_proxy      = Fluent::SlackClient::WebApi.new(nil, proxy_url)

      @icon_url = 'http://www.google.com/s2/favicons?domain=www.google.de'
    end

    def token(client)
      client.is_a?(Fluent::SlackClient::IncomingWebhook) ? {} : {token: ENV['SLACK_API_TOKEN']}
    end

    def default_payload(client)
      {
        channel:   '#general',
        mrkdwn:     true,
        link_names: true,
      }.merge!(token(client))
    end

    def default_attachment
      {
        mrkdwn_in: %w[text fields]
      }
    end

    def valid_utf8_encoded_string
      "#general \xE3\x82\xA4\xE3\x83\xB3\xE3\x82\xB9\xE3\x83\x88\xE3\x83\xBC\xE3\x83\xAB\n"
    end

    def valid_utf16_encoded_string
      str = "#general \xE3\x82\xA4\xE3\x83\xB3\xE3\x82\xB9\xE3\x83\x88\xE3\x83\xBC\xE3\x83\xAB\n"
      str.encode!(Encoding::UTF_16, Encoding::UTF_8)
    end

    def invalid_ascii8bit_encoded_utf8_string
      str = "#general \xE3\x82\xA4\xE3\x83\xB3\xE3\x82\xB9\xE3\x83\x88\xE3\x83\xBC\xE3\x83\xAB\x81\n"
      str.force_encoding(Encoding::ASCII_8BIT)
    end

    # Notification via Mention works for all three with plain text payload
    def test_post_message_plain_payload_mention
      [@incoming, @slackbot, @api].each do |slack|
        assert_nothing_raised do
          slack.post_message(default_payload(slack).merge({
            text: "#general @everyone\n",
          }))
        end
      end
    end

    # Notification via Highlight Words works with only Slackbot with plain text payload
    # NOTE: Please add `sowawa1` to Highlight Words
    def test_post_message_plain_payload_highlight_words
      [@incoming, @slackbot, @api].each do |slack|
        assert_nothing_raised do
          slack.post_message(default_payload(slack).merge({
            text: "sowawa1\n",
          }))
        end
      end
    end

    # Notification via Mention does not work for attachments
    def test_post_message_color_payload
      [@incoming, @slackbot, @api].each do |slack|
        assert_nothing_raised do
          slack.post_message(default_payload(slack).merge({
            attachments: [default_attachment.merge({
              color:    'good',
              fallback: "sowawa1\n@everyone\n",
              text:     "sowawa1\n@everyone\n",
            })]
          }))
        end
      end
    end

    # Notification via Mention does not work for attachments
    def test_post_message_fields_payload
      [@incoming, @slackbot, @api].each do |slack|
        assert_nothing_raised do
          slack.post_message(default_payload(slack).merge({
            attachments: [default_attachment.merge({
              color:    'good',
              fallback: 'test1 test2',
              fields:   [
                {
                  title: 'test1',
                  value: "[07:00:00] sowawa1\n[07:00:00] @everyone\n",
                },
                {
                  title: 'test2',
                  value: "[07:00:00] sowawa1\n[07:00:00] @everyone\n",
                },
              ],
            })]
          }))
        end
      end
    end

    def test_post_via_proxy
      [@incoming_proxy, @slackbot_proxy, @api_proxy].each do |slack|
        assert_nothing_raised do
          slack.post_message(default_payload(slack).merge({
            attachments: [default_attachment.merge({
              color:    'good',
              fallback: "sowawa1\n@everyone\n",
              text:     "sowawa1\n@everyone\n",
            })]
          }))
        end
      end
    end

    def test_post_message_username
      [@incoming, @api].each do |slack|
        assert_nothing_raised do
          slack.post_message(default_payload(slack).merge({
            username: 'fluentd',
            text:     "#general @everyone\n",
          }))
        end
      end
    end

    def test_post_message_icon_url
      [@incoming, @api].each do |slack|
        assert_nothing_raised do
          slack.post_message(default_payload(slack).merge({
            icon_url:    @icon_url,
            attachments: [default_attachment.merge({
              color:    'good',
              fallback: "sowawa1\n@everyone\n",
              text:     "sowawa1\n@everyone\n",
            })]
          }))
        end
      end
    end

    # Hmm, I need to delete channels to test repeatedly,
    # but slack does not provide channels.delete API
    def test_channels_create
      begin
        @api.channels_create(token(@api).merge({
          name: '#test_channels_create',
        }))
      rescue Fluent::SlackClient::NameTakenError
      end
    end

    # Hmm, I need to delete channels to test repeatedly,
    # but slack does not provide channels.delete API
    def test_auto_channels_create
      assert_nothing_raised do
        @api.post_message(default_payload(@api).merge(
          {
            channel:  '#test_auto_api',
            text:     "bar\n",
          }),
          {
            auto_channels_create: true,
          }
        )
      end

      assert_nothing_raised do
        @slackbot.post_message(default_payload(@slackbot).merge(
          {
            channel:  '#test_auto_slackbot',
            text:     "bar\n",
          }),
          {
            auto_channels_create: true,
          }
        )
      end
    end

    # IncomingWebhook posts "#general インストール"
    def test_post_message_utf8_encoded_text
      [@incoming].each do |slack|
        assert_nothing_raised do
          slack.post_message(default_payload(slack).merge({
            text: valid_utf8_encoded_string,
          }))
        end
      end
    end

    # IncomingWebhook posts "#general インストール"
    def test_post_message_utf16_encoded_text
      [@incoming].each do |slack|
        assert_nothing_raised do
          slack.post_message(default_payload(slack).merge({
            text: valid_utf16_encoded_string,
          }))
        end
      end
    end

    # IncomingWebhook posts "#general インストール?"
    def test_post_message_ascii8bit_encoded_utf8_text
      [@incoming].each do |slack|
        assert_nothing_raised do
          slack.post_message(default_payload(slack).merge({
            text: invalid_ascii8bit_encoded_utf8_string,
          }))
        end
      end
    end

    # IncomingWebhook and API posts "#general インストール?"
    def test_post_message_ascii8bit_encoded_utf8_attachments
      [@incoming, @api].each do |slack|
        assert_nothing_raised do
          slack.post_message(default_payload(slack).merge({
            attachments: [default_attachment.merge({
              color:    'good',
              fallback: invalid_ascii8bit_encoded_utf8_string,
              text:     invalid_ascii8bit_encoded_utf8_string,
            })]
          }))
        end
      end
    end
  end
end
