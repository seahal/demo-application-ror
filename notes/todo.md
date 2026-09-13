# Implementation pause notes

- P1–P3 complete on `feature` (authority map; RP Session rename; one Valkey + AUTH_STATE + hiredis).
- Remaining: P4–P9 per `plans/backlog/integrated-auth-boundary-surface-consolidation-plan.md`.
- Local verification used host PostgreSQL 17 + vfs-podman Valkey (compose overlay store was
  corrupt). Prefer single Valkey on :6379 with logical DBs 0/1/2 (and 3/4/5 for test URLs).
- Sign-out `show` exists; one-shot completion page migration and `/sign/out/complete` removal remain
  (P7).
- Empty `*_structure.sql` dumps mean fresh DBs need `db:migrate`.
