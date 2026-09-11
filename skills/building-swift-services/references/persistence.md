# Postgres persistence

Keep every Postgres type in `<Service>Postgres`, except executable configuration and client construction.

## Contents

- Scope and database
- Repositories and statements
- Identifiers, dates, and secrets
- Idempotent writes
- State transitions and liveness-scoped uniqueness
- Database ownership and migrations
- The roles
- Row-level security
- Transaction policy

## Scope and database

A **scope** is what one unit of work may reach. Core declares one protocol per use case naming the repositories it needs (see *Feature structure* in [core.md](core.md)), and the Postgres target conforms one concrete scope per database to `PostgresScope` from swift-persistence-postgres and to every use-case scope its repositories satisfy:

```swift
package struct PostgresCatalogScope: PostgresScope, CreateItemUseCaseScope, ListItemsUseCaseScope {
    package let itemRepository: any ItemRepository

    package init(connection: PostgresConnection, logger: Logger) {
        self.itemRepository = PostgresItemRepository(connection: connection, logger: logger)
    }
}
```

The database is `PostgresDatabase<Scope>` from `PersistencePostgres`, built in the composition root over a `PostgresClient`:

```swift
let database = PostgresDatabase<PostgresCatalogScope>(client: client, logger: logger)
```

`withTransaction` is its only entry point. Every unit of work is a transaction: under row-level security the tenant is set on the transaction and the policy reads it from there, so a read outside one arrives anonymous — and does not fail, it comes back empty. A service with no policies pays a transaction it did not need; a service with them cannot forget. A `PostgresTransactionError` is unwrapped to the error that caused the rollback, so a use case catches the domain error its repository threw rather than a wrapper around it.

At the start of each transaction the database applies `PostgresSettings`: the constant ones it was built with, such as `application_name`, merged with whatever the task's `ServiceContext` carries under `postgresSettings`. Each becomes `set_config(name, value, true)`, transaction-local, so a pooled connection carries nothing to its next borrower. That is how the tenant reaches the policies (*Row-level security* below).

Add repositories to a scope as features are introduced. Do not expose the raw connection to Core, and do not write a `Database`, `PostgresDatabase` or `PostgresScope` of the service's own: those shapes were once duplicated per service and now live in the packages, and a service that redeclares them stops being able to use `<Project>Persistence` or `<Project>Testing`.

A service with more than one database role builds one scope type per database — `PostgresBillingScope`, `PostgresBillingInternalScope`, `PostgresBillingWorkerScope` — each conforming to the use-case scopes that may run over it. That is how a use case declares which database it needs and the compiler refuses the other; see *Row-level security* below.

## Repositories and statements

Use `PostgresPreparedStatement` values in `Statements/<Entity>`. Keep SQL and row decoding there. Repositories execute statements and translate database failures into `XRepositoryError`.

For duplicate detection, inspect the server error code and the exact constraint name. Map SQLSTATE `23505` on the known constraint to the repository error named for that constraint; map other failures to the appropriate repository failure. Do not let `PSQLError` escape into Core.

## Identifiers, dates, and secrets

Use database-owned UUIDv7 identifiers and timestamps (`uuidv7()` is built into PostgreSQL 18):

```sql
CREATE TABLE items (
    id UUID PRIMARY KEY DEFAULT uuidv7(),
    name TEXT NOT NULL UNIQUE,
    creation_date TIMESTAMPTZ NOT NULL DEFAULT NOW()
)
```

The create command omits `id`. The create statement inserts caller-owned fields and returns the complete row, including the generated identifier:

```sql
INSERT INTO items (name)
VALUES ($1)
RETURNING id, name, creation_date
```

Decode identifiers as `UUID`, dates as `Date`, and return a Core entity from the repository. Do not put `id` in a create command; do not put a timestamp there unless time is a true caller-supplied business value. Do not add an identifier-generator protocol or generate entity ids in a use case, repository, workflow, RPC client, or another service.

Name stored dates `creation_date`, `update_date`, `expiration_date`, `consumption_date`, and equivalent noun-based names, with the Swift forms `creationDate`, `updateDate`, `expirationDate`, `consumptionDate`. Do not use `created_at`, `expires_at`, `expiry_date`, or Swift `somethingAt` names. Noun-based names describe the stored value rather than the event, and they convert mechanically between SQL snake case and Swift camel case with no special cases.

Distinguish entity identifiers from non-identifier application secrets such as verification and refresh tokens. Model those as one Core value type that owns both minting and digesting, rather than a generator protocol and a separate hashing helper:

```swift
package struct SecretToken: Equatable, Sendable {
    package let value: String
    package let digest: String

    package init(byteCount: Int = 32)          // mint from CSPRNG bytes, base64url
    package init?(presented value: String)     // wrap what a caller sent back
    private init(digesting value: String)      // both funnel here: value + SHA-256 hex
}
```

`digest` is then never something a call site must remember to derive. Do not add a generator type beside it; a concrete struct with no protocol cannot be substituted, so injecting it buys nothing, and its statics drag verify-only callers into depending on the minting type.

Persist only `digest`, hand `value` to its bearer once, and declare the column `TEXT UNIQUE NOT NULL` with no generation default. Use SHA-256 rather than a password hash: the input is already high entropy, and a deterministic digest is what makes lookup by index possible. Reserve bcrypt for user-chosen passwords. Delete the row when its process reaches a terminal state so no secret outlives the flow that issued it.

## Idempotent writes

Enforce retry safety where the side effect is owned. A caller or workflow supplies one stable, namespaced `idempotencyKey` for a logical mutation; the receiving use case validates it, the command and statement carry it, and the owning database enforces it. Do not rely on an in-memory check, a client-side retry flag, or Temporal history to prevent duplicate writes.

For an idempotent create, put a single-column `UNIQUE` constraint on the column declaration and make conflict handling atomic. PostgreSQL gives the inline constraint the conventional `<table>_<column>_key` name, which `ON CONFLICT` may reference:

```sql
CREATE TABLE items (
    id UUID PRIMARY KEY DEFAULT uuidv7(),
    idempotency_key TEXT UNIQUE,
    name TEXT NOT NULL,
    creation_date TIMESTAMPTZ NOT NULL DEFAULT NOW()
)
```

Keep the column nullable only when explicitly trusted admin, import, or migration paths may create records without retry identity — an ordinary unique constraint permits multiple `NULL` values. Require a non-empty, length-bounded key at every RPC or workflow-backed write boundary that promises idempotency; a `NULL` write has no replay guarantee.

```sql
INSERT INTO items (idempotency_key, name)
VALUES ($1, $2)
ON CONFLICT ON CONSTRAINT items_idempotency_key_key DO UPDATE
SET idempotency_key = EXCLUDED.idempotency_key
WHERE items.name = EXCLUDED.name
RETURNING id, name, creation_date
```

Compare every canonical field that defines the operation, after the service's normal normalization. The same key and input returns the existing database-generated result. The same key with different input returns no row and maps through a repository `.idempotencyConflict` to a use-case conflict. A different key that violates a business constraint remains a normal duplicate error. Never overwrite stored business data with a mismatched retry.

Use compare-and-swap updates for retryable state transitions and stable provider idempotency keys for external side effects such as email or payments. If deleting the result would allow a key to be reused but the product requires longer retention, store operation outcomes in a dedicated idempotency table instead of tying key lifetime to the entity row.

## State transitions and liveness-scoped uniqueness

Guard a state transition in the `WHERE` clause and let the absent row report the loss:

```sql
UPDATE registrations
SET state = $2, update_date = NOW()
WHERE id = $1 AND state = $3
RETURNING id, state, creation_date, expiration_date
```

Returning no row is how a caller learns it lost the race, atomically and without a separate read.

Carry only the destination state in the command. When each transition has one legal predecessor, derive the guard from the destination on the state enum instead of passing both: a second field carries no information the destination does not already imply, only the chance to pass an inconsistent pair. Give the initial state no predecessor so it binds as SQL `NULL`, never matches, and fails closed.

For a business value that must be unique only while a process is live — one in-flight registration per email, one open order per cart — enforce it with a partial unique index over the active states, named `<table>_active_<column>_key`:

```sql
CREATE UNIQUE INDEX registrations_active_email_key
ON registrations (email)
WHERE state IN ('pending', 'verified')
```

Rows in terminal states fall out of the index, so the value frees automatically when the process completes or expires. Scope the predicate to states this service owns the truth about; after the process hands ownership to another service, that service's own constraint is the authority. Map SQLSTATE `23505` on the named index to the matching repository error. Never replace this constraint with a check-then-insert in application code, and never convert the conflict into success by looking up the business value; distinct principals can submit identical business data.

## Database ownership and migrations

### One instance or many

"Database per service" is an ownership rule, not a hardware rule: no shared tables, no cross-service joins, one service evolving each schema. It has two sound physical shapes, and the choice is per environment:

- **One instance per service** — independent scaling, isolated blast radius, per-service versions and maintenance windows. The strict shape; what a managed-database-per-service production naturally gives.
- **One shared instance, one database per service** — the standard small-to-mid-workload shape, and the right default for a single staging box: one well-tuned cluster instead of N sets of `shared_buffers`, autovacuum, and WAL writers. Postgres holds the boundary itself — there are no cross-database queries without an FDW — so a service physically cannot join into a sibling's data. One control completes it: connect rights are granted per role rather than left at Postgres's connect-to-anything default, so a leaked role password cannot even reach a sibling's database.

The environment contract makes the choice invisible to code: `POSTGRES_HOST/PORT/DB/USER/PASSWORD` describes *a database*, not an instance, so moving between shapes is an environment edit. On a shared instance the plain `POSTGRES_USER`/`POSTGRES_PASSWORD` pair is the cluster's administrator verbatim — the same "instance owner, verbatim" contract, now shared — and role names (`<service>_service`) are cluster-wide, which the naming convention already keeps unique.

Either way, **a service's database exists before the service first deploys** — no service ever creates a database. On a per-service instance the image's own variables provision it; on a shared instance an administrator creates `<project>_<service>` explicitly, once, as part of provisioning the application. From there the role model applies unchanged: the service connects to its own isolated database as the owner/administrator pair for migrations at boot, and as the roles its migrations create — `<service>_service` first — for serving and every other data path.

Consolidating existing per-service instances into one cluster is a `pg_dump --no-owner | psql` per database — with one lesson that survives the details: the rights that live *outside* a single database's dump (database-level connect grants, default privileges) do not travel, so re-establish them for the roles the new cluster actually uses, and distrust a quiet boot — a lazily-pooled service hides a missing grant until its first query.

A service owns the whole database. Use unqualified names such as `items`, not `<service>.items`, and do not create a service-named schema.

Name migrations for their result, such as `CreateItemsTable`. Do not prefix a migration with the service name; it already lives inside the service-owned Postgres module. Give each table its own create migration; keep that table's indexes and constraints with it rather than combining several tables into one migration. Keep migrations under `Migrations/<Entity>` and register them explicitly in dependency order in the executable's migration list, parents before children — `serve --migrate-database` applies it at boot (see *Migrations at boot* in composition.md).

Write single-column uniqueness inline, such as `email TEXT NOT NULL UNIQUE`; use table-level `UNIQUE (...)` only for multi-column uniqueness. Do not add `CHECK (... IN (...))` constraints unless the user explicitly requests them.

The migration library refuses a list whose order differs from what a database has already applied — it throws, it does not revert. Appending a migration applies in place; inserting one before applied migrations means a fresh database.

Dropping a table, deleting a migration, or moving data is a destructive product decision. Do it only when the user has chosen the strategy; otherwise finish the non-destructive work and surface the decision.

## The roles

Migrations run as the owner — the instance's own `POSTGRES_USER` / `POSTGRES_PASSWORD`, verbatim — and the owner owns every table. Nothing that serves data ever connects as the owner: Postgres applies no policy to a table's owner, so a service that ran as it could not add row-level security later without changing what it connects as. Every other connection is a role a migration creates, one per way of seeing the data:

| Role | Created by | Policy on a tenant table | Connects |
| --- | --- | --- | --- |
| `<service>_service` | `CreateServiceRole`, the **first** migration | the tenant predicate | `serve`, for public and user use cases |
| `<service>_internal` | `CreateInternalRole` | `USING (true)` | `serve`, for admin use cases and the internal use cases another process calls |
| `<service>_worker` | `CreateWorkerRole` | `USING (true)` | the worker, on its own service's database |

A service with no tenant tables has the service role alone. A tenant service has the internal role too; a service with a Temporal worker has the worker role too. Each has its own secret — `POSTGRES_SERVICE_*`, `POSTGRES_INTERNAL_*`, `POSTGRES_WORKER_*` — so the wider view is a credential held only by the connection that needs it, and a leaked service-role password still sees one tenant.

```swift
let migrations = DatabaseMigrations()
await migrations.add(CreateServiceRole(role: configuration.serviceUser, password: configuration.servicePassword, database: database))
await migrations.add(CreateInternalRole(role: configuration.internalUser, password: configuration.internalPassword, database: database))
await migrations.add(CreateItemsTable())
```

The migration is plain: `CREATE ROLE "<role>" LOGIN PASSWORD '…'`, `GRANT CONNECT` on the database, `GRANT USAGE` on `public`, DML on all tables and usage on all sequences, and the same two as `ALTER DEFAULT PRIVILEGES` so every table a later migration creates is the role's from the moment it exists. `revert` is `DROP ROLE IF EXISTS`. Keep it that simple — no existence checks, no quoting helpers; the values are the deployment's own configuration. The three role migrations are one shape with three names; share the grant list through a private helper in `Migrations/Role/`, not a base class. Roles are cluster-wide, so a database dropped and re-migrated in a cluster that still has the role fails on `CREATE ROLE`; drop the role with the database.

Never `BYPASSRLS`, and never the owner as a runtime role. The wider view is granted `TO` the role through a policy of its own (below), so it is a fact visible in the schema and in `pg_policies` rather than an attribute on a role or a consequence of ownership.

Because the migration library refuses a reordered list, a service that adopts the service role after its tables are applied cannot slide it in first without re-migrating from scratch. Adopt it at the first migration. The internal and worker roles append.

## Row-level security

When a service's rows belong to users — a user's documents, a user's devices, a customer's purchases — confine callers in Postgres, not in the statements. Restating the rule as a scope bound into every query is the same predicate maintained twice, and the copy in the statements is the one that drifts. The rule exists once, as policies; the service tells the database who is calling.

**Row-level security is tenant isolation, nothing more.** The tenant is the user, so every policy is one predicate on one setting, and nothing else reaches the database this way:

```sql
CREATE POLICY user_isolation ON documents
    USING (user_id = NULLIF(current_setting('app.caller_user_id', true), '')::uuid)
    WITH CHECK (user_id = NULLIF(current_setting('app.caller_user_id', true), '')::uuid)
```

Whether a caller is an administrator, and what they may do, is the use case's decision in Swift, against the `subject:` it was handed (see *Authorization lives in the use case* in [identity-and-access.md](identity-and-access.md)). No role travels to the database. A policy that admitted `admin` or `service` beside the tenant would be authorization written twice — once in a use case, once in SQL — with the SQL copy invisible to the use case's tests.

**Stamp the transaction, not the connection.** `<Project>Persistence`'s `UserSettingsInterceptor`, applied on the user service right after the bearer interceptor, turns the bound user into `PostgresSettings.user(_:)` — the one setting, `app.caller_user_id` — in the task's `ServiceContext`, and every transaction begun under that call applies it: `set_config(name, value, true)` with bound parameters, so nothing is spliced into SQL, and transaction-local, so the value reverts at commit and rollback and a pooled connection carries nothing to its next borrower. With no user bound it sets nothing, and a policy then admits no rows — which is what an anonymous transaction on a tenant table deserves. There is no role setting: a policy isolates a tenant, and nothing else travels to the database this way.

`NULLIF` is load-bearing: once a custom setting has been set on a connection, reading it after that transaction yields `''` rather than `NULL`, and `''::uuid` is an error rather than a non-match. A table nobody writes as a user — a grant made by a payment or an administrator — has `WITH CHECK (false)` for the tenant role. A join table is reachable through its parent: a child row's policy is `EXISTS (SELECT 1 FROM parents p WHERE p.id = parent_id AND p.user_id = …)`, and the subquery runs under the parent's own policy.

**Two databases per tenant service, by role.** The predicate above is what the service role sees. The use cases that need every row — an administrator listing, a grant another service makes for a named user — do not get it through a clause in the policy; they get it through a second connection, as the internal role, whose policy on each tenant table is its own:

```sql
CREATE POLICY internal_all ON documents TO "documents_internal" USING (true) WITH CHECK (true)
```

The composition root builds two databases and hands each to the use cases that belong on it, and the scope types keep them apart:

| Database | Role and policy | Tenant setting | Scope | Use cases |
| --- | --- | --- | --- | --- |
| Tenant-scoped | the service role, the tenant predicate | bound by `UserSettingsInterceptor` on the user service | `Postgres<Service>Scope` | public and user |
| Unscoped | the internal role, `USING (true)` | none reaches it: the internal service has no bearer interceptor | `Postgres<Service>InternalScope` | admin, and internal ones another process calls |

```swift
let database = PostgresDatabase<PostgresBillingScope>(client: serviceClient, logger: logger)
let internalDatabase = PostgresDatabase<PostgresBillingInternalScope>(client: internalClient, logger: logger)
```

The two databases are built the same way; what differs is the role each client connects as and which RPC services reach each. The unscoped database sees every row, so every query on it names the user it means in its own `WHERE` clause, and the use case logs every use of it for a named user. An administrator's call arrives with a user bound and a tenant setting applied, and the internal role's `USING (true)` policy ignores it. A use case whose scope protocol is adopted only by the internal scope cannot be built over the tenant-scoped database, and the reverse; that refusal is the compiler's, not a code review's. A service whose one table is the tenant itself — users, where a person's own row and an administrator's any row are one use case deciding — may build only the unscoped database and leave the service role unused; say so in the composition root.

**A worker connects to its own service's database directly**, as the worker role, with the same `USING (true)` policy and its own secret, and builds the unscoped kind of database over `Postgres<Service>WorkerScope` in its own composition root (see *Worker composition* in the orchestrating-temporal-workflows skill). An Activity is inside the service's boundary and its input is durable workflow state rather than a caller's request, so nothing is gained by putting a network hop between it and the tables it owns. A worker never opens another service's database; it calls that service's internal RPC, which runs the use case over that service's unscoped database.

**Which services.** A service whose rows belong to users. Not a table with no owner — a sign-up list is anyone's to add to and an administrator's to read, which is the use case's `.forbidden` guard, not a policy. Not the authenticating service, whose rows are credential material looked up *by secret* on anonymous paths (a refresh token by digest, a registration by email): a `user_id` policy there breaks refresh for everyone. Not a public catalogue.

**`RETURNING` is a read.** Postgres applies the `SELECT` policy to the row an `INSERT … RETURNING` hands back, and a caller the policy excludes gets `new row violates row-level security policy`, not the row. An insert made by a caller who may not read — the anonymous sign-up — must not `RETURNING`, and the RPC then answers with acceptance rather than the record. Change the contract to say so rather than stamping the record's dates in the service.

**Verify as the roles.** Run the service against the roles the policies apply to and probe as a user, another user, an administrator, and a process: the tenant role sees one tenant, the internal and worker roles see everything, and the owner proves nothing because the policies are off for it. Check the policy text itself too (`pg_policies`), since a renamed setting in code and an unrenamed one in a migration already applied fails only at query time.

## Transaction policy

- Every unit of work is `withTransaction`; there is no cheaper entry point, because under row-level security the stamp lives on the transaction.
- Build every repository in a scope from the same supplied connection.
- Never call another service from inside `withTransaction` (the one exception is in [core.md](core.md), *Database boundary*).
- Never make two service databases participate in one transaction.
- For a multi-service process, use orchestration and explicit failure/retry semantics. Add an outbox only when asynchronous delivery requirements call for it.
