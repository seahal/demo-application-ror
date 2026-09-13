# Auth-boundary consolidation evidence (2026-09-13 JST)

Branch: `feature`  
Head at evidence write: `30e833fd4` (continuation after leftover RP-route and SIDE JWT slices).

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
| P6/P7 stale URLs       | `d4c81a1e8`         | Dashboard and sign-out completion helper sweep                                                         |
| P5 leftover RP starts  | `0b7cfbba1`         | Core/Side/Edit `/oidc/authorization`+`/oidc/callback` retired; `/sign/in` is canonical                 |
| P5 SIDE JWT namespaces | `30e833fd4`         | Independent `OIDC_CLIENT_SIDE_*` keys; Core bridges use `core-app`/`core-com`/`core-org`               |

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

## Continuation 2026-09-13 evening (JST)

Focused leftover-route suite: `36 runs, 798 assertions, 0 failures`.  
SIDE/Core first-party focused suite: `78 runs, 654 assertions, 0 failures`.  
Pre-push `bun run test:coverage`: 86 files, 1075 tests; stmts 99.82%, branches 99.71%, lines 99.81%.
Gates held.

Full `bundle exec rails test` (host Postgres + Valkey, `RUBY_DEBUG_OPEN=false`):  
`12989 runs, 78152 assertions, 115 failures, 67 errors, 2 skips` in 636s. Not green.

Focused leftover Root/RP/sign-out suite after this slice: `120 runs, 688 assertions, 0 failures` (1
skip: issue #846 session-limit handoff).

## Remaining gaps vs plan completion conditions

1. **Shared browser clients still registered** (`sign-rp`, `base-rails-rp`, `side-rails-rp`,
   `core-next-rp`). Auth still hardcodes `sign-rp`; Base still hardcodes `base-rails-rp`. Do not
   remove the four IDs until those surfaces stop depending on them. Native/content clients stay.
2. **Full Rails suite is still red** as of `06ed9b64a` (`115` failures / `67` errors). This slice
   retargets leftover Root 301/lobby/Base-RP assertions and wires Base GET `/sign/out` to Inertia.
   Remaining clusters: Edit Publishing `publishing_management_namespace`, compose `valkey-cache`,
   Auth/Base ceremony leftovers, inventory/forbidden-pattern contracts.
3. **P4 call-site migration:** AuthCeremonySession + OpaqueAdmissionStore exist; most Auth/Base
   ceremony controllers not yet migrated onto opaque handoff/result + Base admission.
4. **Compose full stack** (`podman-compose --in-pod=false` primary/replica/valkey/fakecloud) not
   re-validated; host Postgres + Valkey used. Compose contract tests still expect `valkey-cache`.
5. **SIDE surface JWT** (`JWT_SIDE_*` / `SURFACE_NAMESPACES`) was not added. Only OIDC client
   assertion namespaces (`OIDC_CLIENT_SIDE_*`) were wired, matching the existing CORE/EDIT pattern.

## Conclusion

P5 Valkey authorization-code exchange cutover and seven-RP controller/route wiring are pushed on
`feature` with hooks green. Plan absolute completion still requires P4 ceremony call-site migration,
shared-client retirement after seven flows, full Rails/coverage/browser suites, and evidence/ADR
polish for those closures.
