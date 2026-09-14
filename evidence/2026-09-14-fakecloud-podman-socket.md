# 2026-09-14 Podman socket mounted into fakecloud (accepted exception)

A container runtime socket is now mounted into the `fakecloud` service via
`compose.override.yaml`, to obtain a real MSK data plane. This reverses a boundary the repository
had previously chosen and guarded. The risk was raised, restated, and **explicitly accepted by the
user** before the change was made.

## What was added

A new gitignored file, `compose.msk.yaml`:

```yaml
name: umaxicaappsglobaldc
services:
  fakecloud:
    environment:
      DOCKER_HOST: unix:///var/run/docker.sock
    volumes:
      - "${XDG_RUNTIME_DIR}/podman/podman.sock:/var/run/docker.sock:rw"
```

Only the differing keys are set. `image`, `ports`, `command`, and the rest are inherited from
`compose.yaml`, which is unmodified. On this machine `XDG_RUNTIME_DIR` is `/run/user/1000` and
`/run/user/1000/podman/podman.sock` exists (`srw------- mslo mslo`).

### Why a separate file rather than a profile

The block first went into `compose.override.yaml` unprofiled, which meant it applied to every bare
`podman compose up`. Making it opt-in via `profiles:` does not work: **profiles gate an entire
service, not individual keys**, and Compose resolves `profiles:` to the value in the last file that
sets one. A profiled fakecloud override therefore gates fakecloud itself, and a bare
`podman compose up` would stop starting it — taking S3, the one surface actually in use, down with
it. `compose.yaml` deliberately leaves fakecloud unprofiled for that reason, as
`docs/operations/local-aws-fakecloud.md` records.

A separate filename is opt-in by construction: Compose auto-discovers only `compose.override.yaml`,
so `compose.msk.yaml` is read only when named with `-f`.

```bash
podman compose -f compose.yaml -f compose.override.yaml -f compose.msk.yaml up -d fakecloud
```

## What this grants

The `fakecloud` container gains the invoking user's **complete container-management rights**: it can
start any image and bind-mount any host path that user can reach. `fakecloud` is a third-party image
(`ghcr.io/faiscadev/fakecloud`, digest-pinned). This is a substantially larger grant than any port
publication in this repository.

The purpose is that fakecloud backs a provisioned MSK cluster with a real sibling Kafka container,
which it can only spawn through such a socket. Without it, `GetBootstrapBrokers` returns well-formed
addresses with nothing listening.

## What this reverses

`test/tooling/compose_host_port_exposure_test.rb` contained
`test_fakecloud_mounts_no_container_socket`, added specifically so this could not happen quietly:

> No Compose service may mount a container runtime socket. fakecloud serves the MSK control plane
> without one; handing it a socket to gain a real Kafka broker would grant it the invoking user's
> full container-management rights.

**That test is deleted in the current working tree**, as a staged deletion produced by concurrent
work unrelated to this change — not by this change, and not to make room for it. Nothing therefore
fails when the socket mount is present. That absence is a gap in the guard rail, not permission;
recorded here so the two events are not later mistaken for one.

`notes/implementation/fakecloud-aws-development-baseline.md` records that the test was written
precisely to stop a future change from reversing this silently.

## Scope limits that still hold

- **`compose.yaml` is unchanged.** It still mounts no container socket anywhere.
- **The Dev Container is unaffected.** It never names `compose.msk.yaml`.
  `.devcontainer/devcontainer.json` sets
  `dockerComposeFile: ["../compose.yaml", "./compose.yaml"]`, and those explicit `-f` flags
  suppress Compose's auto-discovery of `compose.override.yaml`. `devcontainer up` therefore starts
  a fakecloud **without** the socket. Only a bare `podman compose up` picks the mount up. The two
  paths now differ in privilege, which is worth remembering when a result cannot be reproduced.
- **Not portable.** `${XDG_RUNTIME_DIR}` is UID-dependent, so the path is correct only for this user.
  `notes/implementation/fakecloud-aws-development-baseline.md` gives this as one original reason the
  mount was never put in `compose.yaml`.

## Committing

`compose.override.yaml` **was** a tracked file when this block was first written there, which would
have shipped the socket mount to every developer and to CI. It was untracked and gitignored the same
day, along with `.devcontainer/compose.override.yml`. `compose.msk.yaml`, where the overlay now
lives, is gitignored from the start. Nothing carrying the socket mount is tracked.

## Not verified

Nothing below was run; this host does not run the container stack in this session.

- `podman compose config` — merge result not inspected.
- `podman compose up -d fakecloud` — not started with the mount.
- `podman compose exec fakecloud docker version` / `docker ps` — socket reachability from inside the
  container is unconfirmed.
- Whether fakecloud actually spawns a Kafka broker once it has the socket, and whether
  `GetBootstrapBrokers` then returns a reachable address. **This is the entire point of the change
  and it remains untested.**
