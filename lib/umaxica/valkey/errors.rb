# typed: false
# frozen_string_literal: true

module Umaxica
  module Valkey
    class Error < StandardError; end

    class ConfigurationError < Error; end

    class Unavailable < Error; end

    class SerializationError < Error; end

    class OperationError < Error; end
  end
end
