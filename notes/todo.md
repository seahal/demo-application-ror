# Implementation pause notes

- P1–P3 complete on `feature`.
- P4 foundation landing: AuthCeremonySession models + opaque admission store + `__Host-auth_sid`
  cookie helper (full controller wiring continues with P5–P7).
- Remaining: finish P4 call-site migration as needed, then P5–P9.
- Local verification: host PostgreSQL 17 + vfs-podman Valkey on :6379 (DBs 0/1/2).
