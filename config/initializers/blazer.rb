# typed: false
# frozen_string_literal: true

# `blazer` is a `group :development` gem with `require: false` (Gemfile): Bundler.require never
# auto-requires it, and the gem is not even on the load path outside development, so both the
# require and everything after it must stay inside this guard.
if Rails.env.development?
  require "blazer"

  # Blazer persists a query-audit row on every run by default (Blazer.audit), which needs a
  # `blazer_audits` table this repository has no migration for. Disabling it here keeps this
  # dashboard a read-only add: no new table, no new migration to review.
  Blazer.audit = false
end
