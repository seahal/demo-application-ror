# Base Physical Authority, Auth Ceremony Service, and Seven First-Party RPs

## Status

Accepted (2026-09-13)

Supersedes conflicting authority claims in:

- `adr/acme-sign-core-base-port-boundary.md` where it calls Base an RP or Auth/Sign a special RP
- `adr/sign-residual-idp-surface-retirement.md` where it retains Sign as a special RP framing
- `adr/logout-ceremony-boundary.md` where browser completion is `GET /sign/out/complete`
- `adr/base-lobby-unauthenticated-entry.md` for Base lobby and dashboard-as-home
- `adr/valkey-cache-and-rate-limit-stores.md` and
  `adr/solid-cache-removal-and-valkey-cache-separation.md` for **development/test Valkey service
  topology only** (not for Solid Queue or cache/rate-limit semantics)

Acme remains the conceptual authority vocabulary for shared logout/session services. Base is the
physical Rails Identity Provider and Authorization Server implementation.

## Context

The repository previously mixed Base RP routes, Auth RP routes, shared browser client IDs
(`sign-rp`, `base-rails-rp`, `side-rails-rp`, `core-next-rp`), TokenUsage child sessions, PostgreSQL
authorization codes, Auth JWT ceremony grants, six Auth/Base `/dashboard` homes, Base `/lobby`, and
`/sign/out/complete` completion pages. The consolidation plan requires one authority surface, seven
independent first-party RPs, ceremony-only Auth, Valkey auth-state, Root homes, and one-shot
`GET /sign/out`.

## Decision

### Authority

- **Base** is the sole physical OIDC IdP / Authorization Server surface (`/oauth/*`, discovery,
  JWKS, token, refresh, revocation, userinfo, end-session). Global OAuth/OIDC contracts remain.
- **Auth** is a credential and authentication ceremony service only. It must not act as an OIDC RP,
  store RP callback state, exchange RP tokens, or grant Identity / Base Browser Session / RP Session
  / AAL / authorization policy.
- Auth may keep actor-specific opaque ceremony-local browser sessions (`ClientAuthCeremonySession`,
  `VisitorAuthCeremonySession`, `OperatorAuthCeremonySession`) bound to random-only
  `__Host-auth_sid`. Those sessions are not Base login proof.

### Seven first-party RPs

Exact independent client IDs, keys, faces, browser transactions, and RP Sessions:

`core-app`, `core-com`, `core-org`, `side-app`, `side-com`, `side-org`, `edit-org`

Each exposes exact `GET /sign/in`, `GET /sign/in/callback`, and `/sign/out`. Shared browser
registrations (`sign-rp`, `base-rails-rp`, `side-rails-rp`, `core-next-rp`) are retired after the
seven flows work. Native and content clients remain.

### Session hierarchy

Identity → Base Browser Session (`ClientToken` / `VisitorToken` / `OperatorToken`) → RP Session
(rename of TokenUsage). No polymorphic / STI / generic auth_flows table. Access JWT remains RFC 9068
(~5 minutes + 30s leeway) and normal auth performs no RP Session row lookup.

### Handoff and codes

- Base↔Auth handoff/results: opaque 256-bit, digest-only, 60s, atomic, no JWT ceremony grants.
- OAuth authorization codes live in Valkey (digest key, issued→consumed CAS/tombstone).
- `private_key_jwt` JTI replay remains in PostgreSQL.

### Roots and logout

- Six Auth/Base Roots: Base authenticated Root keeps former Dashboard content/guards; Auth Root is
  always public ceremony entry. Remove six `/dashboard` routes and Base `/lobby`.
- Browser `/sign/out` is a one-shot `show`; retire `/sign/out/complete`. `GET /sign/out` never
  mutates authority state (only presentation-marker consume).

### Edit

Edit is an independent `edit-org` RP. Publishing UI stays on Edit; Publishing DB/domain stay in
Global. Replace Publishing route loops with twelve explicit declarations.

### Canonical map

`AuthBoundaryAuthorityMap` is the written route/authority map for client IDs, faces, retired paths,
and surface roles. Live registries, routes, and docs must converge on it.

## Consequences

- Implementation proceeds as P2–P9 of
  `plans/backlog/integrated-auth-boundary-surface-consolidation-plan.md`.
- Conflicting active ADR statements above are historical where superseded; Jump JWKS on Auth
  remains.
- Preserve Google/Apple/Entra callback contracts, Core/Side/Edit dashboards, and global `/oauth`.
