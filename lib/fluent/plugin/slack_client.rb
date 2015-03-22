require 'uri'
require 'net/http'

module Fluent
  module SlackClient
    class Error < StandardError; end

    # This slack client only supports posting message
    class Base
      attr_accessor :log, :debug_dev

      DEFAULT_ENDPOINT = "https://slack.com/api/chat.postMessage"

      def initialize(endpoint = nil)
        # Configure Incoming Webhook endpoint instead of chat.postMessage API
        @endpoint = URI.parse(endpoint) if endpoint
      end

      def endpoint
        @endpoint ||= URI.parse(DEFAULT_ENDPOINT)
      end

      # Sends a message to a channel.
      #
      # @option params [channel] :channel
      #   Channel to send message to. Can be a public channel, private group or IM channel. Can be an encoded ID, or a name.
      # @option params [Object] :text
      #   Text of the message to send. See below for an explanation of formatting.
      # @option params [Object] :username
      #   Name of bot.
      # @option params [Object] :parse
      #   Change how messages are treated. See below.
      # @option params [Object] :link_names
      #   Find and link channel names and usernames.
      # @option params [Object] :attachments
      #   Structured message attachments.
      # @option params [Object] :unfurl_links
      #   Pass true to enable unfurling of primarily text-based content.
      # @option params [Object] :unfurl_media
      #   Pass false to disable unfurling of media content.
      # @option params [Object] :icon_url
      #   URL to an image to use as the icon for this message
      # @option params [Object] :icon_emoji
      #   emoji to use as the icon for this message. Overrides `icon_url`.
      # @see https://api.slack.com/methods/chat.postMessage
      # @see https://github.com/slackhq/slack-api-docs/blob/master/methods/chat.postMessage.md
      # @see https://github.com/slackhq/slack-api-docs/blob/master/methods/chat.postMessage.json
      def post_message(params = {})
        http = Net::HTTP.new(endpoint.host, endpoint.port)
        http.use_ssl = (endpoint.scheme == 'https')
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE
        http.set_debug_output(debug_dev) if debug_dev

        req = Net::HTTP::Post.new(endpoint.path)
        req['Host'] = endpoint.host
        req['Accept'] = 'application/json; charset=utf-8'
        req['User-Agent'] = 'fluent-plugin-slack'
        req.body = encode_body(params)

        log.info { "out_slack: post #{params.dup.tap {|p| p[:token] = '[FILTERED]' if p[:token] }}" } if log
        res = http.request(req)
        response_check(res)
      end

      def encode_body(params)
        raise NotImplementedError
      end

      def response_check(res)
        if res.code != "200"
          raise Error, "Slack.com - #{res.code} - #{res.body}"
        end
      end
    end

    class IncomingWebhook < Base
      def encode_body(params = {})
        params.to_json
      end

      def response_check(res)
        super
        unless res.body == 'ok'
          raise Error, "Slack.com - #{res.code} - #{res.body}"
        end
      end
    end

    class WebApi < Base
      def encode_body(params = {})
        body = params.dup
        if params[:attachments]
          body[:attachments] = params[:attachments].to_json
        end
        URI.encode_www_form(body)
      end

      def response_check(res)
        super
        params = JSON.parse(res.body)
        unless params['ok']
          raise Error, "Slack.com - #{res.code} - #{res.body}"
        end
      end
    end
  end
end
