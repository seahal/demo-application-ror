# typed: false
# frozen_string_literal: true

module Umaxica
  module Valkey
    module Namespaces
      module_function

      AUTHORIZATION_CODES = "auth_state:authorization_code"
      SIGN_OUT_NOTICES = "auth_state:sign_out_notice"
      ADMISSION = "auth_state:admission"

      def authorization_codes(suite_run_id: nil, worker_id: nil, test_id: nil)
        namespace(AUTHORIZATION_CODES, suite_run_id: suite_run_id, worker_id: worker_id, test_id: test_id)
      end

      def sign_out_notices(suite_run_id: nil, worker_id: nil, test_id: nil)
        namespace(SIGN_OUT_NOTICES, suite_run_id: suite_run_id, worker_id: worker_id, test_id: test_id)
      end

      def admission(suite_run_id: nil, worker_id: nil, test_id: nil)
        namespace(ADMISSION, suite_run_id: suite_run_id, worker_id: worker_id, test_id: test_id)
      end

      def namespace(base, suite_run_id:, worker_id:, test_id:)
        [base, suite_run_id, worker_id, test_id].compact_blank.join(":")
      end
    end
  end
end
