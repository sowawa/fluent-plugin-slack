require 'net/http'

module Fluent
  module SlackClient
    class Error < StandardError
      attr_reader :res, :req_params

      def initialize(res, req_params = {})
        @res        = res
        @req_params = req_params.dup
      end

      def message
        @req_params[:token] = '[FILTERED]' if @req_params[:token]
        "res.code:#{@res.code}, res.body:#{@res.body}, req_params:#{@req_params}"
      end

      alias :to_s :message
    end

    class ChannelNotFoundError < Error; end
    class NameTakenError < Error; end
  end
end
