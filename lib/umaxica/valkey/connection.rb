# typed: false
# frozen_string_literal: true

require "redis"

module Umaxica
  module Valkey
    # The only application-owned entry point for auth-state Valkey commands. Higher-level stores
    # use this adapter rather than constructing Redis clients or issuing commands themselves.
    class Connection
      def initialize(url: ENV.fetch("AUTH_STATE_REDIS_URL"), namespace:, client: nil)
        raise ConfigurationError, "Valkey namespace is required" if namespace.to_s.blank?

        @namespace = namespace.to_s
        @client = client || Redis.new(url: url)
      rescue ArgumentError, URI::InvalidURIError => e
        raise ConfigurationError, "invalid Valkey configuration", cause: e
      end

      attr_reader :namespace

      def key(suffix)
        value = suffix.to_s
        raise ConfigurationError, "Valkey key suffix is blank" if value.blank?
        raise ConfigurationError, "Valkey key suffix contains a separator" if value.include?(" ")

        "#{namespace}:#{value}"
      end

      def call(command, *arguments)
        @client.call(command, *arguments)
      rescue Redis::BaseError, IOError, SystemCallError => e
        raise Unavailable, "Valkey operation unavailable", cause: e
      end

      def close
        @client.close if @client.respond_to?(:close)
      rescue Redis::BaseError, IOError, SystemCallError
        nil
      end
    end
  end
end
