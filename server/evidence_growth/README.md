# Evidence Growth API

The server imports the same router, knowledge registry, review engine and SQLite
Trial service as Android. It does not implement a second set of growth rules.
All routes require a bearer token. Each authenticated user has a separate SQLite
database; public knowledge has a separate database.

From the repository root:

```sh
cd server/evidence_growth
dart pub get
dart run bin/server.dart
```

Provision `EG_TOKEN_USERS` as a JSON mapping of SHA-256 token digests to user IDs
through the deployment secret manager. Use cryptographically random tokens of at
least 32 bytes. The process fails closed when this configuration is absent. Set
`EG_DATA_DIR` to a durable volume. Default binding is `127.0.0.1:8787`; expose it
through a TLS reverse proxy. No live deployment or account is created by this PR.

Implemented PRD routes: `/v1/runtime/route`, `/v1/trials`,
`/v1/trials/{id}/{start,result,review,decision,why}`, `/v1/kb/modules`,
`/v1/kb/nodes/{id}`, `/v1/evidence/summary`, `/v1/feedback/evidence`.
Additional routes: `/v1/kb/search`, `/v1/kb/manifest`, `/v1/sync`,
`DELETE /v1/evidence`.

Mutations accept `Idempotency-Key`. Repeating a stored request returns its stored
response; reusing the key with a different body returns 409. A deterministic
creation ID also prevents duplicate Trials after an interrupted creation response.
The server returns stable error codes without exception text or personal content.

Review responses use the shared deterministic engine and identify only observed
facts; the Android client can additionally use its configured AI provider under
the evidence contract. No server-side provider key is required.

Use the module's CI tests before deployment. Backup both the per-user SQLite
files and public manifest history. Android remains usable while this optional
service is unavailable.
