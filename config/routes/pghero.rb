# typed: false
# frozen_string_literal: true

# PgHero owns the PostgreSQL monitoring dashboard (PgHero::Engine), on its own dedicated host.
# Public canonical host: pghero.umaxica.dev. Development host: pghero.core.dev.localhost.
constraints host: [ENV["PUBLIC_PGHERO_URL"], ENV["PRIVATE_PGHERO_URL"],
                   "pghero.core.dev.localhost",].compact do
  # `pghero` is a `group :development` gem (Gemfile); it is not in the test group's load path,
  # so the engine constant does not exist while running the test suite.
  if defined?(PgHero::Engine)
    # Cloudflare Access fronts this host, but the mounted Rack app must not depend on the edge
    # alone: PgHero::Engine subclasses nothing of this application, so enforce_access_policy! and
    # surface isolation never run for it, and any request that reached the origin directly would
    # get unauthenticated read access to query stats/table stats and the ability to kill running
    # queries.
    #
    # Fails closed: when the credentials are not configured the block returns false and every
    # request is answered with 401, rather than defaulting to open access.
    mount(
      Rack::Auth::Basic.new(PgHero::Engine) do |user, password|
        expected_user = Rails.app.creds.option(:PGHERO_USER)
        expected_password = Rails.app.creds.option(:PGHERO_PASSWORD)

        if expected_user.blank? || expected_password.blank?
          false
        else
          # Non-short-circuiting `&` so both comparisons always run.
          ActiveSupport::SecurityUtils.secure_compare(user.to_s, expected_user) &
            ActiveSupport::SecurityUtils.secure_compare(password.to_s, expected_password)
        end
      end.tap { |app| app.realm = "PgHero" } => "/",
      :as => :pghero,
    )
  end
end
