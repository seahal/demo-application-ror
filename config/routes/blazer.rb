# typed: false
# frozen_string_literal: true

# Blazer owns the SQL exploration dashboard (Blazer::Engine), on its own dedicated host.
# Public canonical host: blazer.umaxica.dev. Development host: blazer.core.dev.localhost.
constraints host: [ENV["PUBLIC_BLAZER_URL"], ENV["PRIVATE_BLAZER_URL"],
                   "blazer.core.dev.localhost",].compact do
  # `blazer` is a `group :development` gem (Gemfile); it is not in the test group's load path,
  # so the engine constant does not exist while running the test suite.
  if defined?(Blazer::Engine)
    # Cloudflare Access fronts this host, but the mounted Rack app must not depend on the edge
    # alone: Blazer::Engine subclasses nothing of this application, so enforce_access_policy! and
    # surface isolation never run for it, and any request that reached the origin directly would
    # get unauthenticated arbitrary read access to every data source Blazer is configured with
    # (config/blazer.yml).
    #
    # Fails closed: when the credentials are not configured the block returns false and every
    # request is answered with 401, rather than defaulting to open access.
    mount(
      Rack::Auth::Basic.new(Blazer::Engine) do |user, password|
        expected_user = Rails.app.creds.option(:BLAZER_USER)
        expected_password = Rails.app.creds.option(:BLAZER_PASSWORD)

        if expected_user.blank? || expected_password.blank?
          false
        else
          # Non-short-circuiting `&` so both comparisons always run.
          ActiveSupport::SecurityUtils.secure_compare(user.to_s, expected_user) &
            ActiveSupport::SecurityUtils.secure_compare(password.to_s, expected_password)
        end
      end.tap { |app| app.realm = "Blazer" } => "/",
      :as => :blazer,
    )
  end
end
