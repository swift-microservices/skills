# Migrations, roles, and row-level security

Where a module's data lives, its tables and the migration list, the roles each process connects as, and the row-level security that confines tenant rows. Scopes, repositories, statements, and transactions are in [persistence.md](persistence.md).

## Contents

- [Database ownership and migrations](#database-ownership-and-migrations)
- [One database, many modules](#one-database-many-modules)
- [The roles](#the-roles)
- [Row-level security](#row-level-security)

## Database ownership and migrations

### Where a service's data lives

"Database per service" is an ownership rule, not a hardware rule: a service creates, migrates, reads, and writes its own tables, and nothing else touches them. Where those tables physically live is decided once for an environment and recorded in the decision record. The default is one Postgres instance with a database and an owner per service; an instance per service or a schema per service is a valid alternative a project records instead. The four shapes, from the most isolated down:

| Shape | Isolation | What it costs | When |
| --- | --- | --- | --- |
| **An instance per service** | Complete: its own failure domain, version, maintenance window, backups, point-in-time recovery, and quotas | N clusters to tune, patch, back up, and pay for; per-instance connection limits | Independent scaling or availability targets, a compliance boundary, a team that runs its own database, a managed-database-per-service platform |
| **One instance, a database per service, distinct owners and roles** (the default) | Logical: Postgres allows no cross-database query without an FDW; each database has its own owner | One failure domain and maintenance window; point-in-time recovery is cluster-wide; role names are cluster-wide; a noisy neighbour shares buffers and I/O | A small or mid-size workload, a single staging box, a managed cluster billed per instance |
| **One database, a schema per service, grants per role** | Weak: a join across schemas is one `GRANT` away, and reviewers must hold the line | Cheapest; a schema owner per service that migrates with `search_path` set to its schema; cross-schema foreign keys become possible and must be refused by review | A platform that provisions databases slowly; move up a row when the first cross-schema join is proposed |
| **Shared tables** | None | Every service couples to every migration | Never; this is the rule the other three exist to keep |

The environment contract makes the choice invisible to code: `POSTGRES_HOST/PORT/DB/USER/PASSWORD` describes *a database*, not an instance, so moving between the first two rows is an environment edit and a `pg_dump --no-owner | psql`. Role names (`<service>_service`) are cluster-wide, so two services or two environments on one instance need distinct names. No service ever creates its database: on a per-service instance the image's own variables provision it; on a shared instance an administrator creates `<project>_<service>` once, while provisioning the application.

Concerns that decide between the rows, in the order they usually bite:

- **Recovery.** Backups are per database; point-in-time recovery is per instance. A service whose data must be restorable to a moment on its own gets its own instance, or accepts logical restores.
- **Pooling.** A pooler in transaction mode hands a connection to a different client per transaction; the tenant setting survives that because it is transaction-local.
- **Replicas.** A read replica serves projections and reports, never a use case: `withTransaction` targets the primary.
- **Connection budgets.** One `PostgresClient` per role per process, sized from the instance's `max_connections` divided across every process and role that connects.
- **Placement and compliance.** Data that must stay in a region or a tenant's own cluster gets its own instance; nothing in the code changes.

Consolidating per-service instances into one cluster is a `pg_dump --no-owner | psql` per database; the rights that live outside one database's dump (database-level connect grants, default privileges) do not travel, so re-establish them for the roles the new cluster uses, and distrust a quiet boot — a lazily-pooled service hides a missing grant until its first query.

### Tables and migrations

A service owns its whole database. Use unqualified names such as `items`, not `<service>.items`, and no schema per module or table group; under the schema-per-service placement the roles' `search_path` points at the service's schema and grants target it instead of `public`.

Name migrations for their result, such as `CreateItemsTable`, without the service name. Give each table its own create migration, with that table's indexes and constraints; keep migrations under `Migrations/<Entity>`. Write single-column uniqueness inline, such as `email TEXT NOT NULL UNIQUE`; use table-level `UNIQUE (...)` only for multi-column uniqueness. Do not add `CHECK (... IN (...))` constraints unless the user explicitly requests them. Each statement is its own `connection.query`:

```swift
// Sources/UsersPostgres/Migrations/User/CreateUsersTable.swift
package import Logging
import PostgresMigrations
package import PostgresNIO

package struct CreateUsersTable: DatabaseMigration {
    package init() {}

    package func apply(connection: PostgresConnection, logger: Logger) async throws {
        try await connection.query(
            """
            CREATE TABLE users (
                id UUID PRIMARY KEY DEFAULT uuidv7(),
                idempotency_key TEXT NOT NULL UNIQUE,
                name TEXT NOT NULL,
                email TEXT NOT NULL UNIQUE,
                status TEXT NOT NULL DEFAULT 'active',
                creation_date TIMESTAMPTZ NOT NULL DEFAULT NOW(),
                update_date TIMESTAMPTZ NOT NULL DEFAULT NOW()
            )
            """,
            logger: logger
        )
    }

    package func revert(connection: PostgresConnection, logger: Logger) async throws {
        try await connection.query("DROP TABLE IF EXISTS users", logger: logger)
    }
}
```

Dropping a table, deleting a migration, or moving data is a destructive product decision. Do it only when the user has chosen the strategy; otherwise finish the non-destructive work and surface the decision.

### The migration list

The executable's `Database/Migrations.swift` is the one migration list, run by the `Migrations` struct in [composition.md](composition.md#migrations-at-boot). It adds every migration explicitly, one `add` per migration, role and table alike, in the order databases apply them: in a new package the role migrations first, `CreateServiceRole` before the others and each reading its password from the configuration, then each module's tables and policies in module dependency order, parents before children. A `<Module>Postgres` declares its migration types and no list of its own; nothing loops over an array of migrations.

The library refuses a list whose order differs from what a database already applied — it throws, it does not revert — so the list only ever appends. A new migration, a new module's migrations, and a role the developer adds later (the internal role when the first tenant table arrives, the worker role with Temporal) go at the end, never before applied ones, with any policy that names the role after it; the role's grant on all tables covers the tables that exist and its default privileges the ones that follow. Inserting before applied migrations means a fresh database.

The list is applied before the process serves: by default `serve --migrate-database`, or a `migrate` one-shot before the rollout, or an apply serialized by an advisory lock, as the project records.

### Polyglot persistence

Postgres is the default store, and everything in this reference assumes it. A module whose measured access pattern is a different shape — documents whose fields vary per record, a key-value lookup at a rate one table cannot serve, full-text search, a time series, a graph — may own a different store, a per-module choice, never per entity and never from taste. The ownership rule does not change.

- A transactional store gets its own driver package in the shape of swift-persistence-postgres (`swift-persistence-<store>`, a `<Store>Database<Scope>`), and the use cases are unchanged.
- A store without transactions gets no `Database`: the use case declares a repository port in Core, a `<Module><Technology>` target adapts the SDK, and the unit of work is one call; a multi-step write to such a store needs an idempotency key on every step.
- **One store is the truth for an entity.** A search index or document view is a projection fed through the outbox (the designing skill's events reference) or a cache, rebuildable from the owner, never written in the same code path as the primary write.
- **Tenant isolation is per store.** Elsewhere than Postgres, isolate by a key prefix, a partition, or a per-tenant collection, chosen once and named in the adapter.
- **No cross-store transaction.** A write that must reach two stores is a saga: the owner writes and publishes, the consumer applies idempotently, with compensation where the second write can fail for good.

## One database, many modules

A monolith has one database, owned by its executable, and every module owns its own tables inside it. The ownership rules between modules are the ones between services, enforced by review rather than by a network: a module creates and migrates its tables, generates its identifiers, and reads and writes them through its own repositories; no other module queries them, joins to them, or declares a foreign key onto them. A relationship across modules is a stored identifier plus a call through the consumer's port. Table names stay unqualified and there is no schema per module, so a module that later becomes a service takes its tables with a `pg_dump` and no renames.

Roles are per process, not per module: a monolith has one set — `<project>_service`, `<project>_internal`, and with Temporal `<project>_worker` — created by migrations in the executable's `Database/Role/`, and one `PostgresClient` per role; each module's scopes are built over the shared clients. Adding a module appends its migrations after every existing module's ([The migration list](#the-migration-list)). A module that owns no tenant table has no policies; the roles exist once for the process regardless.

## The roles

Migrations run as the database's owner — on the default shared instance the per-service owner created at provisioning, which needs `CREATEROLE`; on an instance per service the instance's own `POSTGRES_USER` / `POSTGRES_PASSWORD`; under a schema per service the schema's owner — and the owner owns every table. Nothing that serves data connects as the owner: Postgres applies no policy to a table's owner. Every other connection is a role a migration creates, one per way of seeing the data:

| Role | Created by | Policy on a tenant table | Connects |
| --- | --- | --- | --- |
| `<service>_service` (`<project>_service` in a monolith) | `CreateServiceRole`, usually the first migration | the tenant predicate | `serve`, for public RPCs and the caller's own |
| `<service>_internal` | `CreateInternalRole` | `USING (true)` | `serve`, for administrators' RPCs on tenant tables and `…InternalService` |
| `<service>_worker` | `CreateWorkerRole` | `USING (true)` | the worker, on its own service's database |

A process with no tenant tables has the service role alone; one with tenant tables has the internal role too; one with a Temporal worker has the worker role too, which its own composition root connects as ([worker.md](../../orchestrating-temporal-workflows/references/worker.md)). Each has its own secret — `POSTGRES_SERVICE_*`, `POSTGRES_INTERNAL_*`, `POSTGRES_WORKER_*` — so a leaked service-role password still sees one tenant.

The rule is the separation: the owner migrates and never serves, no role has `BYPASSRLS`, and a tenant-scoped role and an unscoped one are distinct roles with distinct secrets. The names and the migration shape are the default; a project that already names its roles differently, or provisions them outside the list, keeps its naming provided each role exists before any policy that names it and the migration client is the only owner connection.

A role migration grants connect, schema usage, DML on all tables, usage on all sequences, and the same two as default privileges, one `connection.query` per statement, with no existence checks, no base class, and no loop. `CreateInternalRole` and `CreateWorkerRole` are the same shape with their own names:

```swift
// Sources/UsersPostgres/Migrations/Role/CreateServiceRole.swift   (a monolith: Sources/<Project>/Database/Role/)
package import Logging
import PostgresMigrations
package import PostgresNIO

package struct CreateServiceRole: DatabaseMigration {
    private let role: String
    private let password: String
    private let database: String

    package init(role: String, password: String, database: String) {
        self.role = role
        self.password = password
        self.database = database
    }

    package func apply(connection: PostgresConnection, logger: Logger) async throws {
        try await connection.query(PostgresQuery(unsafeSQL: "CREATE ROLE \"\(role)\" LOGIN PASSWORD '\(password)'"), logger: logger)
        try await connection.query(PostgresQuery(unsafeSQL: "GRANT CONNECT ON DATABASE \"\(database)\" TO \"\(role)\""), logger: logger)
        try await connection.query(PostgresQuery(unsafeSQL: "GRANT USAGE ON SCHEMA public TO \"\(role)\""), logger: logger)
        try await connection.query(PostgresQuery(unsafeSQL: "GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO \"\(role)\""), logger: logger)
        try await connection.query(PostgresQuery(unsafeSQL: "GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO \"\(role)\""), logger: logger)
        try await connection.query(PostgresQuery(unsafeSQL: "ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO \"\(role)\""), logger: logger)
        try await connection.query(PostgresQuery(unsafeSQL: "ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT USAGE, SELECT ON SEQUENCES TO \"\(role)\""), logger: logger)
    }

    package func revert(connection: PostgresConnection, logger: Logger) async throws {
        try await connection.query(PostgresQuery(unsafeSQL: "DROP ROLE IF EXISTS \"\(role)\""), logger: logger)
    }
}
```

The values are the deployment's own configuration, so `unsafeSQL` is acceptable here and nowhere a caller's value reaches. Under a schema per service, replace `public` with the service's schema. Roles are cluster-wide, so a database dropped and re-migrated in a cluster that still has the role fails on `CREATE ROLE`; drop the role with the database.

## Row-level security

Row-level security is the default where more than one end user owns rows in one database, and it is not universal. A single-tenant application, an internal tool, a module whose tables are reference data or bookkeeping, or a deployment per customer has no policies and one scope, and a package with no tenant table anywhere has one service role and no settings interceptor or middleware; the decision record says so, and the rest of this section does not apply. Where the tenant is an organization rather than a user, everything below holds with the organization's id in the setting and the predicate.

The rule exists once, as policies, never restated as a predicate bound into every query; the service tells the database who is calling. **Row-level security's main concern is tenant isolation**: the policy on a tenant table is one predicate on one setting, in both `USING` and `WITH CHECK`, so a caller can neither read nor write another tenant's rows, and the internal role sees every row through a policy of its own, `TO` the role, so the wider view is a fact of the schema:

```swift
// Sources/UsersPostgres/Migrations/User/CreateUsersRLSPolicy.swift
package import Logging
import PostgresMigrations
package import PostgresNIO

/// The tenant is the user: users_service sees the caller's row; the internal role sees every row.
package struct CreateUsersRLSPolicy: DatabaseMigration {
    private let internalRole: String

    package init(internalRole: String) {
        self.internalRole = internalRole
    }

    package func apply(connection: PostgresConnection, logger: Logger) async throws {
        try await connection.query("ALTER TABLE users ENABLE ROW LEVEL SECURITY", logger: logger)
        try await connection.query(
            """
            CREATE POLICY user_isolation ON users
                USING (id = NULLIF(current_setting('app.caller_user_id', true), '')::uuid)
                WITH CHECK (id = NULLIF(current_setting('app.caller_user_id', true), '')::uuid)
            """,
            logger: logger
        )
        try await connection.query(
            PostgresQuery(unsafeSQL: "CREATE POLICY internal_all ON users TO \"\(internalRole)\" USING (true) WITH CHECK (true)"),
            logger: logger
        )
    }

    package func revert(connection: PostgresConnection, logger: Logger) async throws {
        try await connection.query("DROP POLICY IF EXISTS internal_all ON users", logger: logger)
        try await connection.query("DROP POLICY IF EXISTS user_isolation ON users", logger: logger)
        try await connection.query("ALTER TABLE users DISABLE ROW LEVEL SECURITY", logger: logger)
    }
}
```

A table whose rows belong to a user rather than being the user compares `user_id` instead of `id`. A policy on a table without row-level security enabled is never applied. With Temporal, the worker role gets the same `TO "<name>_worker" USING (true)` policy, appended after `CreateWorkerRole`.

Whether a caller is an administrator, and what they may do, is the use case's decision in Swift ([identity-and-access.md](identity-and-access.md#authorization-lives-in-the-use-case)). A policy that restated such a decision would be authorization written twice, with the SQL copy invisible to the use case's tests.

**Stamp the transaction, not the connection.** `<Project>Persistence`'s `UserSettingsInterceptor`, applied on `<Entity>Service` right after the bearer interceptor — or `UserSettingsMiddleware` on the identifying tier right after the bearer middleware ([surface.md](../../building-swift-http-surfaces/references/surface.md#the-tenant-on-http)) — turns the bound user into `PostgresSettings.user(_:)`, the one setting `app.caller_user_id`, and every transaction begun under that call applies it with bound parameters, transaction-local. With no user bound it sets nothing, and a policy then admits no rows.

`NULLIF` is load-bearing: once a custom setting has been set on a connection, reading it after that transaction yields `''` rather than `NULL`, and `''::uuid` is an error rather than a non-match. A table nobody writes as a user — a grant made by a payment or an administrator — has `WITH CHECK (false)` for the tenant role. A join table is reachable through its parent: a child row's policy is `EXISTS (SELECT 1 FROM parents p WHERE p.id = parent_id AND p.user_id = …)`.

**Two databases per tenant module, by role.** The composition root builds two databases and hands each to the use cases that belong on it, and the scope types keep them apart:

| Database | Role and policy | Tenant setting | Scope | Use cases |
| --- | --- | --- | --- | --- |
| Tenant-scoped | the service role, the tenant predicate | bound by `UserSettingsInterceptor` on `…Service`, or `UserSettingsMiddleware` on the identifying tier | `Postgres<Module>Scope` | public and the caller's own |
| Unscoped | the internal role, `USING (true)` | ignored | `Postgres<Module>InternalScope` | administrators' and `…InternalService` |

The unscoped database sees every row, so every query on it names the user it means in its own `WHERE` clause, and the use case logs every use of it for a named user. A self-only read is its own use case on the tenant-scoped database and takes no id: a person's own record is `GetProfile`, and an administrator's read of any record by id is `GetUserByID`, a separate RPC and use case on the unscoped database. One RPC never serves both.

**Which tables.** A table whose rows belong to users. Not a table with no owner — a sign-up list is anyone's to add to and an administrator's to read, which is the use case's `.forbidden` guard. Not credential material looked up *by secret* on anonymous paths (a refresh token or a verification token by digest): a `user_id` policy on those breaks refresh for everyone. The account table is a tenant table even though sign-in finds a row by email before any caller is bound: sign-in runs on the internal role and names the email in its own `WHERE` clause, and the person's own profile runs under the tenant policy ([monolith-composition.md](monolith-composition.md#a-monolith-serving-http-and-grpc)). The anonymous sign-up that creates a tenant-scoped profile row has no user bound, so the tenant `WITH CHECK` refuses it; it needs a `FOR INSERT` policy of its own for the service role, with no `RETURNING` (below). Not a public catalogue. A table whose rows become public by their own state — a published recipe beside its author's drafts — keeps the owner predicate in `WITH CHECK` and adds only that state to `USING` (`status = 'published' OR user_id = …`); the state is a column of the row, never the caller's role.

**`RETURNING` is a read.** Postgres applies the `SELECT` policy to the row an `INSERT … RETURNING` hands back, and a caller the policy excludes gets `new row violates row-level security policy`. An insert made by a caller who may not read must not `RETURNING`, and the RPC answers with acceptance rather than the record.

**Verify as the roles.** Run against the roles the policies apply to and probe as a user, another user, an administrator, and a process: the tenant role sees one tenant, the internal and worker roles see everything, and the owner proves nothing because the policies are off for it. Check `pg_policies` too, since a renamed setting in code and an unrenamed one in an applied migration fails only at query time.
