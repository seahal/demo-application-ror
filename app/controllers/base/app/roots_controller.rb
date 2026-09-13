# typed: false
# frozen_string_literal: true

module Base
  module App
    class RootsController < Base::App::ApplicationController
      include ::SurfaceInertiaPage

      AUTHENTICATION_MODE = :open

      def index
        response.headers["Cache-Control"] = "private, no-store"
        return render_authenticated_home if logged_in?

        render inertia: true, props: root_landing_props
      end

      private

      def render_authenticated_home
        return unless require_selected_actor_context_for_root!

        authorize!(current_client, to: :show?)
        render inertia: "base/app/dashboards/show", props: dashboard_page_props
      end

      def require_selected_actor_context_for_root!
        return true if Actor.selection.selected?

        if request.format.json?
          render json: { status: "selection_required", next: base_app_selector_path(ri: params[:ri]) },
                 status: :forbidden
        else
          redirect_to(base_app_selector_path(ri: params[:ri]))
        end
        false
      end

      def dashboard_page_props
        {
          title: t("base.shared.dashboard.title"),
          sections: [
            { heading: t("base.shared.dashboard.sections.primary_links"), items: primary_links },
            { heading: t("base.shared.dashboard.sections.protocol_links"), items: protocol_links },
          ],
        }
      end

      def primary_links
        [
          { label: t("base.shared.dashboard.links.root"), href: base_app_root_path(ri: params[:ri]) },
          { label: t("base.shared.dashboard.links.account"), href: base_app_accounts_path(ri: params[:ri]) },
          { label: t("base.shared.dashboard.links.organization"), href: base_app_organizations_path(ri: params[:ri]) },
          { label: t("base.shared.dashboard.links.avatar"), href: base_app_avatars_path(ri: params[:ri]) },
          { label: t("base.shared.dashboard.links.switcher"), href: base_app_switcher_path(ri: params[:ri]) },
          { label: t("base.shared.dashboard.links.identity"), href: base_app_identity_path(ri: params[:ri]) },
          {
            label: t("base.shared.identity.links.sessions"),
            href: base_app_identity_sessions_path(ri: params[:ri]),
          },
          { label: t("base.shared.dashboard.links.logout"), href: new_base_app_sign_out_path(ri: params[:ri]) },
        ]
      end

      def protocol_links
        [
          {
            label: t("base.shared.dashboard.links.authorize_sign_in"),
            href: ceremony_sign_in_href,
          },
          {
            label: t("base.shared.dashboard.links.authorize_sign_up"),
            href: ceremony_sign_up_href,
          },
          { label: t("base.shared.dashboard.links.oidc_discovery"),
            href: base_app_well_known_openid_configuration_path, },
          { label: t("base.shared.dashboard.links.jwks"), href: base_app_well_known_jwks_path },
          { label: t("base.shared.dashboard.links.userinfo"), href: base_app_oauth_userinfo_path },
        ]
      end

      def root_landing_props
        {
          title: "Base App",
          heading: "Base App",
          description: t("landing.thin_endpoint"),
          sign_in: {
            label: "Sign in",
            href: ceremony_sign_in_href,
          },
          sign_up: {
            label: "Sign up",
            href: ceremony_sign_up_href,
          },
        }
      end

      def ceremony_sign_in_href
        auth_app_sign_in_url(ri: params[:ri], host: oidc_sign_host, protocol: "https")
      end

      def ceremony_sign_up_href
        auth_app_sign_up_url(ri: params[:ri], host: oidc_sign_host, protocol: "https")
      end
    end
  end
end
