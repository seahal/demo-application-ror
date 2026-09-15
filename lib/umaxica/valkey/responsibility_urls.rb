# typed: false
# frozen_string_literal: true

require "uri"

module Umaxica
  module Valkey
    # Parses and validates responsibility Redis/Valkey URLs for nonprod logical DB layout.
    module ResponsibilityUrls
      DEV_DBS = {
        cache: 0,
        rate_limit: 1,
        auth_state: 2,
      }.freeze
      TEST_DBS = {
        cache: 3,
        rate_limit: 4,
        auth_state: 5,
      }.freeze

      Parsed =
        Data.define(:responsibility, :url, :db, :host, :port) do
          def redis_scheme?
            url.start_with?("redis://", "rediss://")
          end
        end

      module_function

      def parse(url, responsibility:)
        responsibility = responsibility.to_sym
        raise ConfigurationError,
              "unknown Valkey responsibility: #{responsibility.inspect}" unless DEV_DBS.key?(responsibility)
        raise ConfigurationError, "Valkey URL is blank" if url.to_s.blank?

        uri = URI.parse(url.to_s)
        raise ConfigurationError, "Valkey URL must use redis or rediss" unless uri.scheme.in?(%w(redis rediss))
        raise ConfigurationError, "Valkey URL host is blank" if uri.host.blank?

        db = extract_db(uri)
        Parsed.new(
          responsibility: responsibility,
          url: url.to_s,
          db: db,
          host: uri.host,
          port: uri.port || 6379,
        )
      rescue URI::InvalidURIError => e
        raise ConfigurationError, "invalid Valkey URL", cause: e
      end

      def expected_db(responsibility, env: Rails.env)
        table = (env.to_s == "test") ? TEST_DBS : DEV_DBS
        table.fetch(responsibility.to_sym)
      end

      def assert_nonprod_db!(parsed, env: Rails.env)
        return unless env.to_s.in?(%w(development test))

        expected = expected_db(parsed.responsibility, env: env)
        return if parsed.db == expected

        raise ConfigurationError,
              "#{parsed.responsibility} Valkey URL DB is #{parsed.db}, expected #{expected} in #{env}"
      end

      def extract_db(uri)
        path = uri.path.to_s.delete_prefix("/")
        return 0 if path.blank?

        Integer(path)
      rescue ArgumentError => e
        raise ConfigurationError, "Valkey URL DB index is invalid", cause: e
      end
    end
  end
end
