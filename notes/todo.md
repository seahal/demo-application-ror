# Implementation pause notes

- The route/root/sign-out slice is currently unverified because Rails boot is blocked by the
  configured PostgreSQL `primary` hostname and the debugger workspace-socket `EPERM` failure.
- The new Valkey auth-state adapters require `AUTH_STATE_REDIS_URL` before exercising a live
  completion or authorization-code exchange. The remaining implementation phases must add that
  responsibility URL to the tracked environment/Compose contracts without editing a developer's
  ignored `.env` file.
- The browser sign-out controllers now expose `show`, but the remaining implementation must finish
  the one-shot completion rendering/page namespace migration and remove every obsolete completion
  helper/reference before the route contract can be considered complete.
