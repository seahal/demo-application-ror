# frozen_string_literal: true

require "minitest/autorun"
require "json"
require "yaml"

# The root-Compose contract. The repository root holds exactly two Compose files:
#
#   compose.yaml           the complete standard environment; no `core`
#   compose.override.yaml  tracked; auto-discovered; everything in it profile-gated
#
#   .devcontainer/compose.yaml         tracked; the Dev Container's own overlay
#   .devcontainer/compose.override.yml tracked; container names
#
# `compose.override.yaml` is auto-discovered by a bare `docker compose` / `podman
# compose`, so anything it adds must sit behind a `profiles:` entry -- otherwise the
# opt-in `remote-access` overlay would replace `core`'s command on every plain `up`.
#
# A fresh `git clone` plus a container engine must be enough to resolve the Compose
# configuration and to open the Dev Container. Nothing may depend on a file the clone
# does not contain, and nothing may depend on a variable the machine has not set.
#
# This reads files as text/JSON, so it needs no container engine and runs in CI.
#
# Plain Minitest::Test, like the other tooling guards, so the assertions below are Minitest's
# `refute_*` rather than the `assert_not_*` forms RuboCop's Rails/RefuteMethods prefers -- those
# are ActiveSupport::TestCase additions and raise NoMethodError here.
# rubocop:disable Rails/RefuteMethods
class ComposeLocalOverrideOptionalTest < Minitest::Test
  REPOSITORY_ROOT = File.expand_path("../..", __dir__)

  # The Compose files a standard development `up` resolves. These are now all of them:
  # the `fdw-poc` experiment overlays were the last files invoked with their own `-f`,
  # and they were removed with the PoC.
  STANDARD_COMPOSE_FILES = %w(
    compose.yaml
    compose.override.yaml
    .devcontainer/compose.yaml
  ).freeze

  # Files the Dev Container loads, and which therefore must resolve on a clean checkout.
  DEVCONTAINER_CONFIG = ".devcontainer/devcontainer.json"

  def test_devcontainer_config_is_strict_json
    # The Dev Containers CLI tolerates comments; other consumers and hand-editing do not,
    # and a stray trailing comma is exactly the kind of thing that only fails on someone
    # else's machine. Parse the comment-stripped text with a strict parser.
    assert_kind_of Hash, devcontainer_configuration
  end

  def test_every_devcontainer_compose_file_is_tracked
    tracked = git_tracked_files

    entries = devcontainer_configuration.fetch("dockerComposeFile")
    entries = [entries] if entries.is_a?(String)

    refute_empty entries

    entries.each do |entry|
      # Entries are relative to devcontainer.json, which lives in .devcontainer/.
      path = File.expand_path(entry, File.join(REPOSITORY_ROOT, ".devcontainer"))
      relative = path.delete_prefix("#{REPOSITORY_ROOT}/")

      assert_path_exists path, "#{entry} is referenced by devcontainer.json but missing"
      assert_includes tracked, relative,
                      "#{entry} is referenced by devcontainer.json but is not tracked by git, " \
                      "so it does not exist on a fresh clone"
    end
  end

  def test_no_tracked_compose_file_requires_a_host_variable
    # `${VAR:?}` is the fresh-clone breaker that is easy to miss: Compose interpolates
    # every listed file in full whichever service is named, so one required variable stops
    # `devcontainer up` on a machine that never runs that service. Opt-in belongs to a
    # `profiles:` entry instead, which is what `cloudflare-tunnel-edge` uses.
    STANDARD_COMPOSE_FILES.each do |relative_path|
      directives = directives_of(relative_path)

      refute_match(
        /\$\{[^}]+:\?/, directives,
        "#{relative_path} uses a required ${VAR:?} interpolation, which breaks a fresh clone",
      )
    end
  end

  def test_the_root_holds_exactly_two_compose_files
    root_files = git_tracked_files.grep(%r{\A[^/]+\z}).grep(/\Acompose.*\.ya?ml\z/).sort

    assert_equal %w(compose.override.yaml compose.yaml), root_files,
                 "the repository root must hold exactly compose.yaml and compose.override.yaml; " \
                 "merge any other root Compose file into one of them"

    gitignore = File.read(File.join(REPOSITORY_ROOT, ".gitignore"))

    refute_match(
      /^\/compose\.override\.yaml$/, gitignore,
      "compose.override.yaml is tracked now and must not be ignored",
    )
  end

  def test_the_root_override_matches_the_current_schema
    override = load_compose("compose.override.yaml")
    base = load_compose("compose.yaml")

    assert_equal base.fetch("name"), override.fetch("name"),
                 "a divergent project name forks the volume set"

    known = base.fetch("services").keys +
      load_compose(".devcontainer/compose.yaml").fetch("services").keys

    override.fetch("services", {}).each_key do |service|
      assert_includes known, service,
                      "the root override names a service no tracked Compose file defines"
    end
  end

  def test_every_service_in_the_root_override_is_profile_gated
    # The file is auto-discovered, so an unprofiled service here would take effect on
    # every bare `docker compose up`. The `remote-access` overlay replaces `core`'s
    # command with sshd, which must never happen implicitly.
    load_compose("compose.override.yaml").fetch("services", {}).each do |name, definition|
      refute_empty Array(definition["profiles"]),
                   "#{name} in compose.override.yaml has no profiles: entry, so it would " \
                   "apply to a bare compose up"
    end
  end

  def test_the_remote_access_overlay_leaves_core_unprofiled_on_the_devcontainer_path
    # Compose takes the LAST value for `profiles:`. The Dev Containers CLI never loads
    # compose.override.yaml, so `core` must stay unprofiled where it is defined.
    core = load_compose(".devcontainer/compose.yaml").fetch("services").fetch("core")

    refute core.key?("profiles"),
           "core must start with the Dev Container lifecycle, not sit behind a profile"

    overlay = load_compose("compose.override.yaml").fetch("services").fetch("core")

    assert_includes overlay.fetch("profiles"), "remote-access"
    assert_equal "/usr/local/bin/remote-sshd-entrypoint", overlay.fetch("command")
  end

  def test_devcontainer_override_names_the_single_nonprod_valkey_from_the_base_compose
    # Nonprod shares one Valkey (logical DBs 0/1/2); see
    # adr/valkey-nonprod-logical-db-topology.md. Dual valkey-cache / valkey-rate-limit
    # services are retired for development/test.
    base_services = load_compose("compose.yaml").fetch("services")
    override_services = load_compose(".devcontainer/compose.override.yml").fetch("services")

    refute_includes base_services, "valkey-cache"
    refute_includes base_services, "valkey-rate-limit"
    refute_includes override_services, "valkey-cache"
    refute_includes override_services, "valkey-rate-limit"

    assert_includes base_services, "valkey"
    assert_includes override_services, "valkey"
    assert_equal base_services.fetch("valkey").fetch("container_name"),
                 override_services.fetch("valkey").fetch("container_name")
  end

  def test_the_primary_tunnel_connector_starts_with_the_devcontainer_stack
    # The Dev Containers CLI starts every unprofiled service in the merged Compose
    # files. Gating the primary connector behind `profiles: [tunnel]` kept
    # `devcontainer up` from creating the sidecar at all, even when
    # CLOUDFLARED_TOKEN was set. The empty-token case is already bounded by
    # `${CLOUDFLARED_TOKEN:-}` plus `restart: on-failure:3`.
    services = YAML.safe_load_file(
      File.join(REPOSITORY_ROOT, "compose.yaml"),
      aliases: true,
    ).fetch("services")
    connector = services.fetch("cloudflare-tunnel")

    refute connector.key?("profiles"),
           "cloudflare-tunnel must start with a plain compose up / Dev Container lifecycle, " \
           "not sit behind a profile the CLI never enables"
    refute connector.key?("depends_on"),
           "a Compose dependency becomes a container dependency under Podman and breaks " \
           "the Dev Containers CLI's --remove-existing-container"
  end

  def test_the_tunnel_connector_keeps_the_process_alive_across_transport_loss
    # Pinning `--protocol quic` disables the documented HTTP/2 fallback. After a
    # laptop sleep or UDP 7844 blip, cloudflared can drain every HA connection and
    # exit 0 ("no more connections active and exiting"). `restart: on-failure`
    # does not recreate a container that exited 0, which is the "tunnel dies and
    # stays dead" report. `auto` still prefers QUIC (Workers VPC allows `auto` or
    # `quic`) and falls back instead of exiting.
    # https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/configure-tunnels/run-parameters/#protocol
    # https://developers.cloudflare.com/workers-vpc/configuration/tunnel/
    command = YAML.safe_load_file(
      File.join(REPOSITORY_ROOT, "compose.yaml"),
      aliases: true,
    ).fetch("services").fetch("cloudflare-tunnel").fetch("command")

    assert_includes command, "--protocol auto"
    assert_includes command, "--no-autoupdate"
    refute_includes command, "--protocol quic"
  end

  def test_the_edge_tunnel_connector_is_opt_in_by_profile
    services = YAML.safe_load_file(
      File.join(REPOSITORY_ROOT, "compose.yaml"),
      aliases: true,
    ).fetch("services")
    connector = services.fetch("cloudflare-tunnel-edge")

    assert_includes connector.fetch("profiles"), "tunnel-edge"
    refute connector.key?("depends_on"),
           "a Compose dependency becomes a container dependency under Podman and breaks " \
           "the Dev Containers CLI's --remove-existing-container"
  end

  def test_the_tunnel_connectors_differ_only_in_profile_and_token
    # The second connector merges the first, so the pinned cloudflared release, the QUIC
    # command, the `frontend` attachment, and the crash-loop caps cannot drift apart. This
    # asserts the merge is still in place after any edit to either service.
    services = YAML.safe_load_file(
      File.join(REPOSITORY_ROOT, "compose.yaml"),
      aliases: true,
    ).fetch("services")

    primary = services.fetch("cloudflare-tunnel")
    edge = services.fetch("cloudflare-tunnel-edge")

    assert_equal %w(environment profiles),
                 (primary.keys | edge.keys).reject { |key| primary[key] == edge[key] }.sort,
                 "the two connectors must share every setting except their profile and token"
    assert_equal({ "TUNNEL_TOKEN" => "${CLOUDFLARED_TOKEN:-}" }, primary.fetch("environment"))
    assert_equal({ "TUNNEL_TOKEN" => "${CLOUDFLARED_EDGE_TOKEN:-}" }, edge.fetch("environment"))
  end

  def test_workers_vpc_connector_is_dedicated_and_starts_with_the_devcontainer_stack
    services = load_compose("compose.yaml").fetch("services")
    primary = services.fetch("cloudflare-tunnel")
    workers_vpc = services.fetch("cloudflare-tunnel-workers-vpc")

    assert_equal ["environment"],
                 (primary.keys | workers_vpc.keys)
                   .reject { |key| primary[key] == workers_vpc[key] }
                   .sort,
                 "the Workers VPC connector must inherit the pinned image, QUIC command, " \
                 "private network, and bounded restart policy from the primary connector"
    assert_equal(
      { "TUNNEL_TOKEN" => "${CLOUDFLARED_WORKERS_VPC_TOKEN:-}" },
      workers_vpc.fetch("environment"),
    )
    refute workers_vpc.key?("profiles"),
           "the dedicated Workers VPC connector must start with the Dev Container stack"
    refute workers_vpc.key?("depends_on"),
           "Podman container dependencies break Dev Containers CLI recreation"
  end

  private

  def load_compose(relative_path)
    YAML.safe_load_file(File.join(REPOSITORY_ROOT, relative_path), aliases: true)
  end

  def devcontainer_configuration
    source = File.read(File.join(REPOSITORY_ROOT, DEVCONTAINER_CONFIG))
    JSON.parse(source.gsub(%r{^\s*//.*$}, ""))
  end

  def git_tracked_files
    @git_tracked_files ||= IO.popen(["git", "-C", REPOSITORY_ROOT, "ls-files"], &:read).split("\n")
  end

  # Compose text with its comment lines removed, so prose about a rule cannot satisfy or
  # violate the rule.
  def directives_of(relative_path)
    File.read(File.join(REPOSITORY_ROOT, relative_path))
      .lines
      .reject { |line| line.lstrip.start_with?("#") }
      .join
  end
end
# rubocop:enable Rails/RefuteMethods
