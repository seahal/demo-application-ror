# Auth-boundary consolidation evidence (2026-09-13 JST)

Branch: `feature`  
Head at evidence write: see `git log -1 --oneline` after P9 commit.

## Environment

- Host PostgreSQL 17 on `127.0.0.1:5432` (compose overlay store was corrupt).
- Valkey via vfs-podman (`vcache` on `:6379`); logical DBs 0/1/2 used for
  cache/rate-limit/auth-state in local helpers.
- Rails tests executed inside persistent `rails-dev` (`ruby:4.0.6-trixie`, host network).

## Phase landings (pushed to `origin/feature`)

| Phase | Tip SHA (short)                 | Notes                                                |
| ----- | ------------------------------- | ---------------------------------------------------- |
| P1    | `106a447a7` (+ earlier ADR/map) | Authority ADR + AuthBoundaryAuthorityMap             |
| P2    | `7bdb40bdc`                     | TokenUsage → RpSession; JWT-only Access auth         |
| P3    | `58ed3f1e6`                     | One Valkey; AUTH_STATE_REDIS_URL; hiredis; stores    |
| P4    | `54fea648e`                     | AuthCeremonySession + OpaqueAdmissionStore           |
| P5    | `3e8c64320`                     | Seven first-party RP client registrations            |
| P6    | `d9a691615`                     | Auth/Base dashboards + lobby removed                 |
| P7    | `d02eeced2`                     | `/sign/out/complete` + CompletionsController removed |
| P8    | `80e1b27ef`                     | Twelve explicit Edit Publishing route declarations   |
| P9    | (this commit)                   | Docs/evidence + targeted verification                |

## Targeted verification executed

### Rails (49 runs / 459 assertions — green)

```
bundle exec rails test \
  test/values/auth_boundary_authority_map_test.rb \
  test/integration/routes/auth_boundary_authority_inventory_test.rb \
  test/models/rp_session_test.rb \
  test/operations/rp_session_revoker_test.rb \
  test/lib/umaxica/valkey \
  test/services/valkey/auth_state \
  test/models/auth_ceremony_session_test.rb \
  test/values/oidc_seven_first_party_rp_clients_test.rb \
  test/integration/routes/auth_base_root_contract_test.rb \
  test/integration/routes/sign_out_oneshot_contract_test.rb \
  test/integration/routes/edit_publishing_explicit_routes_test.rb
```

Result: `49 runs, 459 assertions, 0 failures, 0 errors, 0 skips`.

### JavaScript

- `bun run test:coverage` — Statements/Lines ~99.86%, Branches ~99.71%, Functions 100%.
- Pre-push `frontend-check` passed on each phase push (oxfmt/oxlint/typecheck/knip/openapi/vite).

## Remaining gaps vs plan completion conditions

These are **not** claimed complete:

1. **P5 follow-through:** OAuth authorization codes still issued/consumed via PostgreSQL
   `*AuthorizationCode` models; Valkey `AuthorizationCodeStore` is tested but not yet the exchange
   coordinator path. Deprecated shared clients (`sign-rp`, `core-next-rp`, …) remain registered for
   migration compatibility.
2. **P4 call-site migration:** AuthCeremonySession / opaque admission are foundation-only; most
   ceremony controllers still use prior session/JWT handoff machinery.
3. **Full Rails suite / SimpleCov gate:** not re-run end-to-end in this session (multi-DB parallel
   workers require careful DB prepare; targeted suites above are green).
4. **Browser history / E2E:** not executed in this session.

## Conclusion

Phases P1–P9 each have a focused commit+push on `feature` with hooks green. Architectural foundation
and route/inventory closures for P6–P8 are in place. Treat the plan’s absolute completion conditions
as **partially satisfied** until the P5 exchange cutover, ceremony call-site migration, and full
Rails/CI suite are finished.
