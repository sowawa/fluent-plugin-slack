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
    end

    def token(client)
      client == @api ? {token: ENV['TOKEN']} : {}
    end

    def test_text
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

    def test_fields
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
  end
end
