# typed: false
# frozen_string_literal: true

require "test_helper"

class TestEnvironmentIsolationContractTest < ActiveSupport::TestCase
  test "test boot uses an explicit PostgreSQL host and test-only Valkey databases" do
    database_config = Rails.root.join("config/database.yml").read

    assert_match(/test_host\s*=\s*Rails\.env\.test\?\s*\?\s*ENV\.fetch\("POSTGRESQL_TEST_HOST"\)/, database_config)
    assert_no_match(/ENV\.fetch\("POSTGRESQL_TEST_HOST",/, database_config)

    %i(cache rate_limit auth_state).each do |responsibility|
      parsed = Umaxica::Valkey::ResponsibilityUrls.parse(
        ENV.fetch("#{responsibility.to_s.upcase}_REDIS_URL"),
        responsibility: responsibility,
      )

      assert_equal(
        Umaxica::Valkey::ResponsibilityUrls.expected_db(responsibility, env: "test"),
        parsed.db,
      )
    end
  end

  test "application auth-state namespaces include the isolated run and worker" do
    scope = Umaxica::Valkey::Namespaces.runtime_scope

    assert_equal ENV.fetch("VALKEY_NAMESPACE_RUN_ID"), scope.fetch(:suite_run_id)
    assert_equal ENV.fetch("VALKEY_NAMESPACE_WORKER_ID"), scope.fetch(:worker_id)
    assert_includes(
      Umaxica::Valkey::Namespaces.authorization_codes(**scope),
      ":#{ENV.fetch("VALKEY_NAMESPACE_RUN_ID")}:#{ENV.fetch("VALKEY_NAMESPACE_WORKER_ID")}",
    )
  end

  test "a default authorization-code store writes inside the isolated scope" do
    Valkey::AuthState::AuthorizationCodeStore.new.issue!(
      client_id: "e0-contract",
      redirect_uri: "https://example.test/callback",
      subject: "e0-subject",
      code_challenge: "e0-challenge",
      code_challenge_method: "S256",
      resource_type: "client",
    )

    connection = Umaxica::Valkey::Connection.new(
      url: ENV.fetch("AUTH_STATE_REDIS_URL"),
      namespace: "e0_contract_probe",
    )
    run_id = ENV.fetch("VALKEY_NAMESPACE_RUN_ID")
    worker_id = ENV.fetch("VALKEY_NAMESPACE_WORKER_ID")
    cursor, keys = connection.call(
      "SCAN",
      "0",
      "MATCH",
      "auth_state:authorization_code:#{run_id}:#{worker_id}:*",
    )

    assert_equal "0", cursor.to_s
    assert_equal 1, keys.length
  ensure
    connection&.close
  end

  test "test services are non-delivering by default" do
    assert_equal :test, Rails.application.config.action_mailer.delivery_method
    assert_equal "test", Rails.application.config.sms_provider
    assert_equal "TurnstileVerifierStub", Rails.application.config.x.turnstile.verifier
  end
end
