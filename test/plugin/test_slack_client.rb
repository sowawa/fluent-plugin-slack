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
#     TOKEN=XXXXX
#
Dotenv.load
if ENV['WEBHOOK_URL'] and ENV['SLACKBOT_URL'] and ENV['TOKEN']

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
    def setup
      super
      @incoming       = Fluent::SlackClient::IncomingWebhook.new(ENV['WEBHOOK_URL'])
      @slackbot       = Fluent::SlackClient::Slackbot.new(ENV['SLACKBOT_URL'])
      @api            = Fluent::SlackClient::WebApi.new

      @proxy          = TestProxyServer.new.tap {|proxy| proxy.start }
      @incoming_proxy = Fluent::SlackClient::IncomingWebhook.new(ENV['WEBHOOK_URL'], @proxy.proxy_url)
      @slackbot_proxy = Fluent::SlackClient::Slackbot.new(ENV['SLACKBOT_URL'], @proxy.proxy_url)
      @api_proxy      = Fluent::SlackClient::WebApi.new(nil, @proxy.proxy_url)

      @icon_url = 'http://www.google.com/s2/favicons?domain=www.google.de'
    end

    def teardown
      @proxy.shutdown
    end

    def token(client)
      client.is_a?(Fluent::SlackClient::IncomingWebhook) ? {} : {token: ENV['TOKEN']}
    end

    def test_post_message_text
      [@incoming, @slackbot, @api].each do |slack|
        assert_nothing_raised do
          slack.post_message(
            {
              channel:     '#general',
              username:    'fluentd',
              icon_emoji:  ':question:',
              attachments: [{
                color:    'good',
                fallback: "sowawa1\nsowawa2\n",
                text:     "sowawa1\nsowawa2\n",
              }]
            }.merge(token(slack))
          )
        end
      end
    end

    def test_post_message_fields
      [@incoming, @slackbot, @api].each do |slack|
        assert_nothing_raised do
          slack.post_message(
            {
              channel:     '#general',
              username:    'fluentd',
              icon_emoji:  ':question:',
              attachments: [{
                color:    'good',
                fallback: 'test1 test2',
                fields:   [
                  {
                    title: 'test1',
                    value: "[07:00:00] sowawa1\n[07:00:00] sowawa2\n",
                  },
                  {
                    title: 'test2',
                    value: "[07:00:00] sowawa1\n[07:00:00] sowawa2\n",
                  },
                ],
              }]
            }.merge(token(slack))
          )
        end
      end
    end

    def test_post_via_proxy
      [@incoming_proxy, @slackbot_proxy, @api_proxy].each do |slack|
        assert_nothing_raised do
          slack.post_message(
            {
              channel:     '#general',
              username:    'fluentd',
              icon_emoji:  ':question:',
              attachments: [{
                color:    'good',
                fallback: "sowawa1\nsowawa2\n",
                text:     "sowawa1\nsowawa2\n",
              }]
            }.merge(token(slack))
          )
        end
      end
    end

    def test_post_message_icon_url
      [@incoming, @api].each do |slack|
        assert_nothing_raised do
          slack.post_message(
            {
              channel:     '#general',
              username:    'fluentd',
              icon_url:    @icon_url,
              attachments: [{
                color:    'good',
                fallback: "sowawa1\nsowawa2\n",
                text:     "sowawa1\nsowawa2\n",
              }]
            }.merge(token(slack))
          )
        end
      end
    end

    def test_post_message_text_mrkdwn
      [@incoming, @api].each do |slack|
        assert_nothing_raised do
          slack.post_message(
            {
              channel:     '#general',
              username:    'fluentd',
              attachments: [{
                color:    'good',
                fallback: "plain *bold* _italic_ `preformat`\n", # mrkdwn not work
                text:     "plain *bold* _italic_ `preformat`\n",
                mrkdwn_in: ['text', 'fields'],
              }]
            }.merge(token(slack))
          )
        end
      end
    end

    def test_post_message_fields_mrkdwn
      [@incoming, @api].each do |slack|
        assert_nothing_raised do
          slack.post_message(
            {
              channel:     '#general',
              username:    'fluentd',
              attachments: [{
                color:    'good',
                fallback: "plain *bold* _italic_ `preformat`\n", # mrkdwn not work
                fields:   [
                  {
                    title: 'plain *bold* _italic* `preformat`', # mrkdwn not work
                    value: "plain *bold* _italic* `preformat`\n",
                  },
                ],
                mrkdwn_in: ['text', 'fields'],
              }]
            }.merge(token(slack))
          )
        end
      end
    end

    # Hmm, I need to delete channels to test repeatedly,
    # but slack does not provide channels.delete API
    def test_channels_create
      begin
        @api.channels_create(
          {
            name: '#test_channels_create',
          }.merge(token(@api))
        )
      rescue Fluent::SlackClient::NameTakenError
      end
    end

    # Hmm, I need to delete channels to test repeatedly,
    # but slack does not provide channels.delete API
    def test_auto_channels_create
      assert_nothing_raised do
        @api.post_message(
          {
            channel:     '#test_auto_api',
            username:    'fluentd',
            icon_emoji:  ':question:',
            attachments: [{
              color:    'good',
              fallback: "bar\n",
              text:     "bar\n",
            }]
          }.merge(token(@api)),
          {
            auto_channels_create: true,
          }
        )
      end

      assert_nothing_raised do
        @slackbot.post_message(
          {
            channel:     '#test_auto_slackbot',
            username:    'fluentd',
            icon_emoji:  ':question:',
            attachments: [{
              color:    'good',
              fallback: "bar\n",
              text:     "bar\n",
            }]
          }.merge(token(@api)),
          {
            auto_channels_create: true,
          }
        )
      end
    end
  end
end
