# Implementation pause notes

- P1 (authority ADR + AuthBoundaryAuthorityMap + inventory contracts) is complete on `feature`.
- Remaining: P2–P9 per `plans/backlog/integrated-auth-boundary-surface-consolidation-plan.md`.
- Local verification used host PostgreSQL 17 + vfs-podman Valkey (compose overlay store was
  corrupt).
- `AUTH_STATE_REDIS_URL` still needs tracked `.env.example` / Compose / `.env.devcontainer.example`
  (do NOT edit ignored `.env`) before live Valkey auth-state exercises (P3/P7).
- Sign-out `show` exists; one-shot completion page migration and `/sign/out/complete` removal remain
  (P7).
- Empty `*_structure.sql` dumps mean fresh DBs need `db:migrate` (with `create_unlogged_tables` skip
  on the client_external_identities LOGGED migration).
