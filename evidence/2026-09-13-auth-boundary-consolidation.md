# Auth-boundary consolidation evidence (2026-09-13 JST)

Branch: `feature`  
Head at evidence write: `898fc6ea4` (see also Valkey cutover `9e4b71856`).

## Environment

- Host PostgreSQL 17 on `127.0.0.1:5432`.
- Valkey via vfs-podman on `:6379`; logical DBs 0/1/2 for cache/rate-limit/auth-state.
- `RUBY_DEBUG_OPEN=false`, `TMPDIR=/tmp/umaxica-vitest`.
- Rails tests with `bundle exec rails test` on the box (`ruby 4.0.6`).

## Phase landings (pushed to `origin/feature`)

| Phase                  | Tip SHA (short)     | Notes                                                                                                  |
| ---------------------- | ------------------- | ------------------------------------------------------------------------------------------------------ |
| P1–P9 skeleton         | through `ddab9d314` | Prior session foundations                                                                              |
| P5 Valkey code cutover | `9e4b71856`         | Issue+exchange on Valkey CAS; PG `*AuthorizationCode` dropped; JTI stays in PG                         |
| P5 seven-RP wiring     | `898fc6ea4`         | Core/Side/Edit client IDs; `/sign/in`+`/sign/in/callback`; Edit Org RP; Auth/Base RP `/oidc/*` retired |

## Verification executed this session

### Valkey authorization-code cutover

```
bundle exec rails test \
  test/services/valkey/auth_state/authorization_code_store_test.rb \
  test/services/oidc/token_exchange_service_test.rb \
  test/services/oidc/authorize_service_test.rb \
  test/services/branch_coverage_batch3_services_test.rb \
  test/services/anomaly_reporting_and_authorize_failures_test.rb \
  test/controllers/palm/app/oidc/callbacks_controller_test.rb
```

Result (after model drop + migrate): `102 runs, 381 assertions, 0 failures, 0 errors` (one transient
batch3 binding error fixed; recheck green).

Earlier focused cutover suite before model deletion:
`94 runs, 356 assertions, 0 failures, 0 errors`.

### Seven-RP registry

```
bundle exec rails test test/values/oidc_seven_first_party_rp_clients_test.rb
```

Result: `2 runs, 69 assertions, 0 failures, 0 errors`.

Route recognition spot-check: Core/Side/Edit `/sign/in` and `/sign/in/callback` resolve; Base/Auth
`/oidc/callback` raise `RoutingError`; Base `/oauth/authorize` remains.

Pre-push `frontend-check` passed on both pushes.

## Remaining gaps vs plan completion conditions

1. **Shared browser clients still registered** (`sign-rp`, `base-rails-rp`, `side-rails-rp`,
   `core-next-rp`) until seven end-to-end browser flows are proven. Legacy `/oidc/callback` still
   mounted beside `/sign/in/callback` on Core/Side for compatibility.
2. **P4 call-site migration:** AuthCeremonySession + OpaqueAdmissionStore exist; most Auth/Base
   ceremony controllers not yet migrated onto opaque handoff/result + Base admission.
3. **Full Rails suite + SimpleCov + browser E2E:** not re-run end-to-end this session. Some route
   contract tests still assert retired `/dashboard` and `/sign/out/complete` (stale vs P6/P7).
4. **Side RP JWT namespaces** still use `BASE_*` key material (not independent `SIDE_*` namespaces).
5. **Compose bring-up** (`podman-compose --in-pod=false` primary/replica/valkey/fakecloud) not
   re-validated as a full stack in this session (host Postgres + Valkey used).

## Conclusion

P5 Valkey authorization-code exchange cutover and seven-RP controller/route wiring are pushed on
`feature` with hooks green. Plan absolute completion still requires P4 ceremony call-site migration,
shared-client retirement after seven flows, full Rails/coverage/browser suites, and evidence/ADR
polish for those closures.
