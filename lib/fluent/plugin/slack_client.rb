require 'uri'
require 'net/http'
require 'net/https'
require 'logger'
require_relative 'slack_client/error'

module Fluent
  module SlackClient
    # The base framework of slack client
    class Base
      attr_accessor :log, :debug_dev
      attr_reader   :endpoint, :https_proxy

      # @param [String] endpoint
      #
      #     (Incoming Webhook) required
      #     https://hooks.slack.com/services/XXX/XXX/XXX
      #
      #     (Slackbot) required
      #     https://xxxx.slack.com/services/hooks/slackbot?token=XXXXX
      #
      #     (Web API) optional and default to be
      #     https://slack.com/api/
      #
      # @param [String] https_proxy (optional)
      #
      #     https://proxy.foo.bar:port
      #
      def initialize(endpoint = nil, https_proxy = nil)
        self.endpoint    = endpoint    if endpoint
        self.https_proxy = https_proxy if https_proxy
        @log = Logger.new('/dev/null')
      end

      def endpoint=(endpoint)
        @endpoint    = URI.parse(endpoint)
      end

      def https_proxy=(https_proxy)
        @https_proxy = URI.parse(https_proxy)
        @proxy_class = Net::HTTP.Proxy(@https_proxy.host, @https_proxy.port)
      end

      def proxy_class
        @proxy_class ||= Net::HTTP
      end

      def post(endpoint, params)
        http = proxy_class.new(endpoint.host, endpoint.port)
        http.use_ssl = (endpoint.scheme == 'https')
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE
        http.set_debug_output(debug_dev) if debug_dev

        req = Net::HTTP::Post.new(endpoint.request_uri)
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

      def filter_params(params)
        params.dup.tap {|p| p[:token] = '[FILTERED]' if p[:token] }
      end

      # Required to implement to use #with_channels_create
      # channels.create API is available from only Slack Web API
      def api
        raise NotImplementedError
      end

      def with_channels_create(params = {}, opts = {})
        retries = 1
        begin
          yield
        rescue ChannelNotFoundError => e
          if params[:token] and opts[:auto_channels_create]
            log.warn "out_slack: channel \"#{params[:channel]}\" is not found. try to create the channel, and then retry to post the message."
            api.channels_create({name: params[:channel], token: params[:token]})
            retry if (retries -= 1) >= 0 # one time retry
          else
            raise e
          end
        end
      end

      def to_json_with_scrub! (params)
        retries = 1
        begin
          params.to_json
        rescue Encoding::UndefinedConversionError => e
          recursive_scrub!(params)
          if (retries -= 1) >= 0 # one time retry
            log.warn "out_slack: to_json `#{params}` failed. retry after scrub!. #{e.backtrace[0]} / #{e.message}"
            retry
          else
            raise e
          end
        end
      end

      def recursive_scrub!(params)
        case params
        when Hash
          params.each {|k, v| recursive_scrub!(v)}
        when Array
          params.each {|elm| recursive_scrub!(elm)}
        when String
          params.force_encoding(Encoding::UTF_8) if params.encoding == Encoding::ASCII_8BIT
          params.scrub!('?') if params.respond_to?(:scrub!)
        else
          params
        end
      end
    end

    # Slack client for Incoming Webhook
    # https://api.slack.com/incoming-webhooks
    class IncomingWebhook < Base
      def initialize(endpoint, https_proxy = nil)
        super
      end

      def post_message(params = {}, opts = {})
        log.info { "out_slack: post_message #{params}" }
        post(endpoint, params)
      end

      private

      def encode_body(params = {})
        # https://api.slack.com/docs/formatting
        to_json_with_scrub!(params).gsub(/&/, '&amp;').gsub(/</, '&lt;').gsub(/>/, '&gt;')
      end

      def response_check(res, params)
        super
        unless res.body == 'ok'
          raise Error.new(res, params)
        end
      end
    end

    # Slack client for Slackbot Remote Control
    # https://api.slack.com/slackbot
    class Slackbot < Base
      def initialize(endpoint, https_proxy = nil)
        super
      end

      def api
        @api ||= WebApi.new(nil, https_proxy)
      end

      def post_message(params = {}, opts = {})
        raise ArgumentError, "channel parameter is required" unless params[:channel]
        with_channels_create(params, opts) do
          log.info { "out_slack: post_message #{filter_params(params)}" }
          post(slackbot_endpoint(params), params)
        end
      end

      private

      def slackbot_endpoint(params)
        endpoint.dup.tap {|e| e.query += "&channel=#{URI.encode(params[:channel])}" }
      end

      def encode_body(params = {})
        return params[:text]if params[:text]
        unless params[:attachments]
          raise ArgumentError, 'params[:text] or params[:attachments] is required'
        end
        # handle params[:attachments]
        attachment = Array(params[:attachments]).first # see only the first for now
        # {
        #   attachments: [{
        #     text: "HERE",
        #   }]
        # }
        text = attachment[:text]
        # {
        #   attachments: [{
        #     fields: [{
        #       title: "title",
        #       value: "HERE",
        #     }]
        #   }]
        # }
        if text.nil? and attachment[:fields]
          text = Array(attachment[:fields]).first[:value] # see only the first for now
        end
        text
      end

      def response_check(res, params)
        if res.body == 'channel_not_found'
          raise ChannelNotFoundError.new(res, params)
        elsif res.body != 'ok'
          raise Error.new(res, params)
        end
      end
    end

    # Slack client for Web API
    class WebApi < Base
      DEFAULT_ENDPOINT = "https://slack.com/api/".freeze

      def api
        self
      end

      def endpoint
        @endpoint ||= URI.parse(DEFAULT_ENDPOINT)
      end

      def post_message_endpoint
        @post_message_endpoint    ||= URI.join(endpoint, "chat.postMessage")
      end

      def channels_create_endpoint
        @channels_create_endpoint ||= URI.join(endpoint, "channels.create")
      end

      # Sends a message to a channel.
      #
      # @see https://api.slack.com/methods/chat.postMessage
      # @see https://github.com/slackhq/slack-api-docs/blob/master/methods/chat.postMessage.md
      # @see https://github.com/slackhq/slack-api-docs/blob/master/methods/chat.postMessage.json
      def post_message(params = {}, opts = {})
        with_channels_create(params, opts) do
          log.info { "out_slack: post_message #{filter_params(params)}" }
          post(post_message_endpoint, params)
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
        log.info { "out_slack: channels_create #{filter_params(params)}" }
        post(channels_create_endpoint, params)
      end

      private

      def encode_body(params = {})
        body = params.dup
        if params[:attachments]
          body[:attachments] = to_json_with_scrub!(params[:attachments])
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
