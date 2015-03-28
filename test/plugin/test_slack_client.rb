require_relative '../test_helper'
require 'fluent/plugin/slack_client'
require 'time'
require 'dotenv'

# HOW TO RUN
#
# Create .env file with contents as:
#
#     WEBHOOK_URL=https://hooks.slack.com/services/XXXX/YYYY/ZZZZ
#     TOKEN=XXXXX
#
Dotenv.load
if ENV['WEBHOOK_URL'] and ENV['TOKEN']
  class SlackClientTest < Test::Unit::TestCase
    def setup
      super
      @incoming_webhook = Fluent::SlackClient::IncomingWebhook.new(ENV['WEBHOOK_URL'])
      @api = Fluent::SlackClient::WebApi.new
      @icon_url = 'http://www.google.com/s2/favicons?domain=www.google.de'
    end

    def token(client)
      client == @api ? {token: ENV['TOKEN']} : {}
    end

    def test_post_message_text
      [@incoming_webhook, @api].each do |slack|
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
      [@incoming_webhook, @api].each do |slack|
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

    def test_post_message_icon_url
      [@incoming_webhook, @api].each do |slack|
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

    # Hmm, I need to delete channels to test repeatedly,
    # but slack does not provide channels.delete API
    def test_channels_create
      begin
        @api.channels_create(
          {
            name: '#foo',
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
            channel:     '#bar',
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
