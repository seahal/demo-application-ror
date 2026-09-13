# Valkey Nonprod Logical DB Topology

## Status

Accepted (2026-09-13).

Supersedes the **development/test physical-service isolation** claims in
`adr/valkey-cache-and-rate-limit-stores.md` and
`adr/solid-cache-removal-and-valkey-cache-separation.md`. Production continues to use separate
responsibility URLs; logical DB indexes are not a security or failure-domain boundary.

## Context

Auth-boundary consolidation needs a third Valkey responsibility (`AUTH_STATE_REDIS_URL`) for
short-lived authorization codes and sign-out presentation markers. Running three Compose services
locally for cache, rate-limit, and auth-state over-fits nonprod and conflicts with the integrated
plan's one-service / six-logical-DB layout.

## Decision

**Development and test share one Valkey service and one volume.** Responsibilities stay named in
URLs (never a generic `REDIS_URL`):

| Responsibility         | Dev DB | Test DB |
| ---------------------- | ------ | ------- |
| `CACHE_REDIS_URL`      | 0      | 3       |
| `RATE_LIMIT_REDIS_URL` | 1      | 4       |
| `AUTH_STATE_REDIS_URL` | 2      | 5       |

Application code talks only through `Umaxica::Valkey::Connection` for auth-state and through the
existing Rails cache / rate-limit stores for the other two contracts. Auth-state keys are namespaced
(`auth_state:*`) and further isolated in tests with `suite_run_id` / `worker_id` / `test_id`.
Cleanup uses prefix SCAN + DEL; tests never call `FLUSHALL` / `FLUSHDB`.

The Redis client uses `hiredis-client` (`driver: :hiredis`) on the locked `redis-client` version.
Driver selection is verified in tests.

**Production** keeps independently configured responsibility URLs and may still use separate hosts;
this ADR does not force logical DBs in production.

## Consequences

- Local Compose exposes one Valkey port; cache maintenance can affect rate-limit and auth-state only
  if operators point tools at the wrong DB index — document the table above and prefer
  responsibility URLs over ad-hoc `valkey-cli -n`.
- Losing the single nonprod volume loses all three stores together; that is acceptable for
  reconstructible cache/rate-limit/auth-state ephemeral data.
