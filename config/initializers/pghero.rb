# typed: false
# frozen_string_literal: true

# `pghero` is a `group :development` gem with `require: false` (Gemfile): Bundler.require never
# auto-requires it, and the gem is not even on the load path outside development, so the require
# must stay inside this guard.
require "pghero" if Rails.env.development?
