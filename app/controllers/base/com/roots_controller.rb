# typed: false
# frozen_string_literal: true

module Base
  module Com
    class RootsController < Base::Com::ApplicationController
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

        authorize!(current_visitor, to: :show?)
        render inertia: "base/com/dashboards/show", props: dashboard_page_props
      end

      def require_selected_actor_context_for_root!
        return true if Actor.selection.selected?

        if request.format.json?
          render json: { status: "selection_required", next: base_com_selector_path(ri: params[:ri]) },
                 status: :forbidden
        else
          redirect_to(base_com_selector_path(ri: params[:ri]))
        end
        false
      end

      def dashboard_page_props
        {
          title: t("base.shared.dashboard.title"),
          description: t("base.shared.dashboard.description"),
          sections: [
            { heading: t("base.shared.dashboard.sections.primary_links"), items: primary_links },
            { heading: t("base.shared.dashboard.sections.protocol_links"), items: protocol_links },
          ],
        }
      end

      def primary_links
        [
          { label: t("base.shared.dashboard.links.root"), href: base_com_root_path(ri: params[:ri]) },
          { label: t("base.shared.dashboard.links.account"), href: base_com_accounts_path(ri: params[:ri]) },
          { label: t("base.shared.dashboard.links.organization"), href: base_com_organizations_path(ri: params[:ri]) },
          { label: t("base.shared.dashboard.links.identity"), href: base_com_identity_path(ri: params[:ri]) },
          { label: t("base.shared.dashboard.links.selector"), href: base_com_selector_path(ri: params[:ri]) },
          { label: t("base.shared.dashboard.links.logout"), href: new_base_com_sign_out_path(ri: params[:ri]) },
        ]
      end

      def protocol_links
        [
          {
            label: t("base.shared.dashboard.links.authorize_sign_in"),
            href: base_com_oidc_authorization_path(ri: params[:ri], screen_hint: "signin"),
          },
          {
            label: t("base.shared.dashboard.links.authorize_sign_up"),
            href: base_com_oidc_authorization_path(ri: params[:ri], screen_hint: "signup"),
          },
          { label: t("base.shared.dashboard.links.oidc_discovery"), href: base_com_well_known_openid_configuration_path },
          { label: t("base.shared.dashboard.links.jwks"), href: base_com_well_known_jwks_path },
          { label: t("base.shared.dashboard.links.userinfo"), href: base_com_oauth_userinfo_path },
        ]
      end

      def root_landing_props
        {
          title: "Base Com",
          heading: "Base Com",
          description: t("landing.thin_endpoint"),
          sign_in: {
            label: "Sign in",
            href: base_com_oidc_authorization_path(ri: params[:ri], screen_hint: "signin"),
          },
          sign_up: {
            label: "Sign up",
            href: base_com_oidc_authorization_path(ri: params[:ri]),
          },
        }
      end
    end
  end
end
