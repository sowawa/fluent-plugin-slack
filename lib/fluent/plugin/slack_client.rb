require 'uri'
require 'net/http'
require 'logger'
require_relative 'slack_client/error'

module Fluent
  module SlackClient
    # The base framework of slack client
    class Base
      attr_accessor :log, :debug_dev

      def initialize
        @log = Logger.new('/dev/null')
      end

      def post(endpoint, params)
        http = Net::HTTP.new(endpoint.host, endpoint.port)
        http.use_ssl = (endpoint.scheme == 'https')
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE
        http.set_debug_output(debug_dev) if debug_dev

        req = Net::HTTP::Post.new(endpoint.path)
        req['Host'] = endpoint.host
        req['Accept'] = 'application/json; charset=utf-8'
        req['User-Agent'] = 'fluent-plugin-slack'
        req.body = encode_body(params)

        res = http.request(req)
        response_check(res, params)
      end

      private

      def encode_body(params)
        raise NotImplementedError
      end

      def response_check(res, params)
        if res.code != "200"
          raise Error.new(res, params)
        end
      end
    end

    # Slack client for Incoming Webhook
    class IncomingWebhook < Base
      attr_accessor :endpoint

      # @param [String] endpoint Configure Incoming Webhook endpoint
      def initialize(endpoint)
        super()
        @endpoint = URI.parse(endpoint)
      end

      def post_message(params = {}, opts = {})
        log.info { "out_slack: post_message #{params}" }
        post(endpoint, params)
      end

      private

      def encode_body(params = {})
        params.to_json
      end

      def response_check(res, params)
        super
        unless res.body == 'ok'
          raise Error.new(res, params)
        end
      end
    end

    # Slack client for Web API
    class WebApi < Base
      DEFAULT_ENDPOINT = "https://slack.com/api/".freeze

      def post_message_endpoint
        @post_message_endpoint    ||= URI.join(DEFAULT_ENDPOINT, "chat.postMessage")
      end

      def channels_create_endpoint
        @channels_create_endpoint ||= URI.join(DEFAULT_ENDPOINT, "channels.create")
      end

      # Sends a message to a channel.
      #
      # @see https://api.slack.com/methods/chat.postMessage
      # @see https://github.com/slackhq/slack-api-docs/blob/master/methods/chat.postMessage.md
      # @see https://github.com/slackhq/slack-api-docs/blob/master/methods/chat.postMessage.json
      def post_message(params = {}, opts = {})
        retries = 1
        begin
          log.info { "out_slack: post_message #{params.dup.tap {|p| p[:token] = '[FILTERED]' if p[:token] }}" }
          post(post_message_endpoint, params)
        rescue ChannelNotFoundError => e
          if opts[:auto_channels_create]
            log.warn "out_slack: channel \"#{params[:channel]}\" is not found. try to create the channel, and then retry to post the message."
            channels_create({name: params[:channel], token: params[:token]})
            retry if (retries -= 1) >= 0 # one time retry
          else
            raise e
          end
        end
      end

      # Creates a channel.
      #
      # NOTE: Bot user can not create a channel. Token must be issued by Normal User Account
      # @see https://api.slack.com/bot-users
      #
      # @see https://api.slack.com/methods/channels.create
      # @see https://github.com/slackhq/slack-api-docs/blob/master/methods/channels.create.md
      # @see https://github.com/slackhq/slack-api-docs/blob/master/methods/channels.create.json
      def channels_create(params = {}, opts = {})
        log.info { "out_slack: channels_create #{params.dup.tap {|p| p[:token] = '[FILTERED]' if p[:token] }}" }
        post(channels_create_endpoint, params)
      end

      private

      def encode_body(params = {})
        body = params.dup
        if params[:attachments]
          body[:attachments] = params[:attachments].to_json
        end
        URI.encode_www_form(body)
      end

      def response_check(res, params)
        super
        res_params = JSON.parse(res.body)
        return if res_params['ok']
        case res_params['error']
        when 'channel_not_found'
          raise ChannelNotFoundError.new(res, params)
        when 'name_taken'
          raise NameTakenError.new(res, params)
        else
          raise Error.new(res, params)
        end
      end
    end
  end
end
