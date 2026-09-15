# Isolated Rails test environment

Rails tests use explicit test-only PostgreSQL databases and Valkey logical databases. A test
process must not inherit the development host or the development Valkey databases.

The supported host-native entry point is:

```bash
POSTGRESQL_TEST_HOST=primary.dns.podman \
POSTGRESQL_PORT=5432 \
POSTGRESQL_USER=root \
POSTGRESQL_PASSWORD='<test-service-password>' \
POSTGRESQL_DATABASE=db \
CACHE_REDIS_URL=redis://valkey.dns.podman:6379/3 \
RATE_LIMIT_REDIS_URL=redis://valkey.dns.podman:6379/4 \
AUTH_STATE_REDIS_URL=redis://valkey.dns.podman:6379/5 \
PARALLEL_WORKERS=1 \
scripts/test-isolated bin/rails test test/path/to/file_test.rb
```

The wrapper performs read-only identity checks before Rails boots. It verifies that PostgreSQL
has `test_*` databases on the selected server and that the three Valkey URLs use logical DBs 3,
4, and 5. It never creates or drops a database. Database preparation remains an explicit command
against the same test host, for example `scripts/test-isolated bin/rails db:prepare` after the
test databases already exist.

`POSTGRESQL_TEST_HOST` is required by `config/database.yml`; it does not fall back to
`POSTGRESQL_HOST`. The test environment also requires all three Valkey URLs and a
`VALKEY_NAMESPACE_RUN_ID`. Application auth-state stores add the run and worker identifiers to
their namespaces. On exit, `scripts/test-isolated` deletes only that run's authorization-code,
admission, and sign-out-notice prefixes with `SCAN` and `DEL`. `FLUSHDB` and `FLUSHALL` are
forbidden.

The test boundary already prevents provider delivery: Action Mailer uses the `:test` delivery
method, the SMS provider is `test`, and Turnstile is replaced by `TurnstileVerifierStub`. Tests
that exercise outbound HTTP use `OutboundHttpStub` and Faraday's test adapter; application HTTP
clients remain behind `OutboundHttp::Connection` so a test can stub the boundary without touching
the transport globally. No real IdP, email, SMS, or provider request is part of this setup.

The wrapper is intentionally separate from `bin/rails test`: a bare invocation without explicit
test service variables must fail at boot rather than silently use development resources.
