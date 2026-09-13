# typed: false
# frozen_string_literal: true

# Writes/reads random-only __Host-auth_sid. Cookie value is the opaque sid only.
module AuthCeremonySidCookie
  extend ActiveSupport::Concern

  COOKIE_NAME = "__Host-auth_sid"
  COOKIE_TTL = AuthCeremonySession::DEFAULT_TTL

  public

  def write_auth_ceremony_sid_cookie!(raw_sid, expires_at: COOKIE_TTL.from_now)
    cookies[COOKIE_NAME] = {
      value: raw_sid,
      expires: expires_at,
      secure: true,
      httponly: true,
      same_site: :lax,
      path: "/",
    }
  end

  def read_auth_ceremony_sid_cookie
    cookies[COOKIE_NAME].presence
  end

  def clear_auth_ceremony_sid_cookie!
    cookies.delete(COOKIE_NAME, path: "/")
  end
end
