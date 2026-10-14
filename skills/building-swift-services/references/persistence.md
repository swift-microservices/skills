# Postgres persistence

Keep every Postgres type in the module's `<Module>Postgres` target (`<Service>Postgres` when the module is a service), except executable configuration and client construction. The rules are the same in a monolith and in a service; what differs is how many modules share one database, which [One database, many modules](#one-database-many-modules) covers.

## Contents

- [Scope and database](#scope-and-database)
- [Repositories and statements](#repositories-and-statements)
- [Identifiers, dates, and secrets](#identifiers-dates-and-secrets)
- [Idempotent writes](#idempotent-writes)
- [State transitions and liveness-scoped uniqueness](#state-transitions-and-liveness-scoped-uniqueness)
- [Database ownership and migrations](#database-ownership-and-migrations)
  - [Where a service's data lives](#where-a-services-data-lives)
  - [Tables and migrations](#tables-and-migrations)
  - [The migration list](#the-migration-list)
  - [Polyglot persistence](#polyglot-persistence)
- [One database, many modules](#one-database-many-modules)
- [The roles](#the-roles)
- [Row-level security](#row-level-security)
- [Caching](#caching)
- [Transaction policy](#transaction-policy)

## Scope and database

A **scope** is what one unit of work may reach. Core declares one protocol per use case naming the repositories it needs ([core.md](core.md#feature-structure)), and the Postgres target conforms one concrete scope per database role to `PostgresScope` and to every use-case scope that may run over that role:

```swift
// Sources/UsersPostgres/Scopes/PostgresUsersScope.swift
package import Logging
import PersistencePostgres
package import PostgresNIO
package import UsersCore

/// The tenant-scoped database, as users_service: a signed-in user's own operations.
package struct PostgresUsersScope: PostgresScope, GetProfileUseCaseScope {
    package let userRepository: any UserRepository

    package init(connection: PostgresConnection, logger: Logger) {
        self.userRepository = PostgresUserRepository(connection: connection, logger: logger)
    }
}
```

`PostgresUsersInternalScope` is the same struct conforming to the administrators' and the internal use cases' scopes, and `Postgres<Module>WorkerScope` to the worker's. A use case whose scope protocol only the internal scope adopts cannot be built over the tenant-scoped database, and the compiler, not a review, refuses it. Build every repository in a scope from the same supplied connection; Core sees repositories through the scope, never the connection.

The database is `PostgresDatabase<Scope>` from `PersistencePostgres`, built in the composition root over a `PostgresClient`. `withTransaction` is its only entry point, for the reason in [core.md](core.md#database-boundary). A `PostgresTransactionError` is unwrapped to the error that caused the rollback, so a use case catches the domain error its repository threw. The callback's isolation contract — nonescaping, caller-isolated, no `@Sendable`, nothing retained past it — is the building-swift-server-libraries skill's ([api.md](../../building-swift-server-libraries/references/api.md#scoped-callbacks-and-isolation)); never return or store a scope, repository, connection, or row stream.

At the start of each transaction the database applies `PostgresSettings`: its constant ones, such as `application_name`, merged with whatever the task's `OperationContext` carries. Each becomes `set_config(name, value, true)`, transaction-local, so a pooled connection carries nothing to its next borrower. That is how the tenant reaches the policies ([Row-level security](#row-level-security)).

## Repositories and statements

One `PostgresPreparedStatement` per query in `Statements/<Entity>/`, holding the SQL, the bindings, and the row decoding:

```swift
// Sources/UsersPostgres/Statements/User/CreateUserStatement.swift
import PostgresNIO
import UsersCore

struct CreateUserStatement: PostgresPreparedStatement {
    static let sql = """
        INSERT INTO users (idempotency_key, name, email)
        VALUES ($1, $2, $3)
        ON CONFLICT ON CONSTRAINT users_idempotency_key_key DO UPDATE
        SET idempotency_key = EXCLUDED.idempotency_key
        WHERE users.name = EXCLUDED.name AND users.email = EXCLUDED.email
        RETURNING id, name, email, status, creation_date, update_date
        """

    let command: CreateUserCommand

    func makeBindings() throws -> PostgresBindings {
        var bindings = PostgresBindings()
        bindings.append(command.idempotencyKey)
        bindings.append(command.name)
        bindings.append(command.email)
        return bindings
    }

    func decodeRow(_ row: PostgresRow) throws -> User {
        try User(row: row)
    }
}
```

The entity's statements share one decoding initializer beside them, selecting the columns in the same order:

```swift
// Sources/UsersPostgres/Statements/User/User+PostgresRow.swift
import PostgresNIO
import UsersCore

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

extension User {
    init(row: PostgresRow) throws {
        let (id, name, email, status, creationDate, updateDate) = try row.decode(
            (UUID, String, String, UserStatus, Date, Date).self
        )
        self.init(id: id, name: name, email: email, status: status, creationDate: creationDate, updateDate: updateDate)
    }
}
```

A Core enum stored as text gets its Postgres conformances in `Extensions/`, refusing a value it does not recognize:

```swift
// Sources/UsersPostgres/Extensions/UserStatus+PostgresCodable.swift
package import PostgresNIO
package import UsersCore

extension UserStatus: PostgresNonThrowingEncodable {
    package static var psqlType: PostgresDataType { .text }
    package static var psqlFormat: PostgresFormat { .binary }

    package func encode(into byteBuffer: inout ByteBuffer, context: PostgresEncodingContext<some PostgresJSONEncoder>) {
        rawValue.encode(into: &byteBuffer, context: context)
    }
}

extension UserStatus: PostgresDecodable {
    package init(
        from byteBuffer: inout ByteBuffer,
        type: PostgresDataType,
        format: PostgresFormat,
        context: PostgresDecodingContext<some PostgresJSONDecoder>
    ) throws {
        let rawValue = try String(from: &byteBuffer, type: type, format: format, context: context)
        guard let value = UserStatus(rawValue: rawValue) else {
            throw PostgresDecodingError.Code.failure
        }
        self = value
    }
}
```

The repository executes statements and translates the failures it knows. Core never matches on `PSQLError`; a repository translates the SQLSTATEs it knows — `23505` on a named constraint — into `XRepositoryError` and lets an unknown cause propagate to the use case's catch-all, which logs it and maps it to `.unknown`:

```swift
// Sources/UsersPostgres/Repositories/User/PostgresUserRepository.swift
import AsyncAlgorithms
import Logging
import PostgresNIO
import UsersCore

struct PostgresUserRepository: UserRepository {
    let connection: PostgresConnection
    let logger: Logger

    func create(_ command: CreateUserCommand) async throws -> User {
        let statement = CreateUserStatement(command: command)
        do {
            let result = try await connection.execute(statement, logger: logger)
            for try await user in result {
                return user
            }
            // ON CONFLICT … WHERE returns no row only for the same key with different input.
            throw UserRepositoryError.idempotencyConflict
        } catch let error as PSQLError where error.serverInfo?[.sqlState] == "23505" {
            switch error.serverInfo?[.constraintName] {
            case "users_email_key":
                throw UserRepositoryError.duplicateEmail
            default:
                throw error
            }
        }
    }

    func list() async throws -> [User] {
        let result = try await connection.execute(ListUsersStatement(), logger: logger)
        return try await Array(result)
    }
}
```

Name a repository error for the constraint that exists: a partial unique index over active states means "an active record exists", not "duplicate email".

## Identifiers, dates, and secrets

The owning database generates service-owned identifiers and stamps persistence-owned dates. Externally assigned standard/provider identifiers, such as WebAuthn credential IDs, are validated and preserved; they may be command fields and primary keys without a generated UUID, and they are not retry keys. For service-generated UUIDs, default: `uuidv7()`, built into PostgreSQL 18, whose time-ordered values keep the primary-key index local. Alternative: `gen_random_uuid()` on an older instance; nothing in Swift changes.

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

Decode service-generated identifiers as `UUID`, external identifiers in their standard type, dates as `Date`, and return a Core entity. Do not put a service-generated `id` in a create command, or a timestamp unless time is a true caller-supplied business value. Do not add an identifier-generator protocol or generate service-owned ids in a use case, repository, workflow, RPC client, or another service.

Name stored dates as nouns: `creation_date`, `update_date`, `expiration_date`, `consumption_date`, with the Swift forms `creationDate`, `updateDate`, `expirationDate`, `consumptionDate`; never `created_at`, `expires_at`, `expiry_date`, or Swift `somethingAt`. The names convert mechanically between snake case and camel case.

Distinguish entity identifiers from non-identifier application secrets such as verification and refresh tokens. Model those as one Core value type that owns both minting and digesting:

```swift
package struct SecretToken: Equatable, Sendable {
    package let value: String
    package let digest: String

    package init(byteCount: Int = 32)          // mint from CSPRNG bytes, base64url
    package init?(presented value: String)     // wrap what a caller sent back
    private init(digesting value: String)      // both funnel here: value + SHA-256 hex
}
```

Do not add a generator type beside it. Persist only `digest`, hand `value` to its bearer once, and declare the column `TEXT UNIQUE NOT NULL` with no generation default. Use SHA-256 rather than a password hash: the input is already high entropy, and a deterministic digest makes lookup by index possible. Reserve bcrypt for user-chosen passwords. Delete the row when its process reaches a terminal state.

## Idempotent writes

Enforce retry safety where the side effect is owned. A caller or workflow supplies one stable, namespaced `idempotencyKey` for a logical mutation; the receiving use case validates it, the command and statement carry it, and the owning database enforces it. Do not rely on an in-memory check, a client-side retry flag, or Temporal history.

For an idempotent create, put a single-column `UNIQUE` constraint on the column and make conflict handling atomic. PostgreSQL names the inline constraint `<table>_<column>_key`, which `ON CONFLICT` may reference:

```sql
CREATE TABLE items (
    id UUID PRIMARY KEY DEFAULT uuidv7(),
    idempotency_key TEXT UNIQUE,
    name TEXT NOT NULL,
    creation_date TIMESTAMPTZ NOT NULL DEFAULT NOW()
)
```

Keep the column nullable only when trusted admin, import, or migration paths create records without retry identity — an ordinary unique constraint permits multiple `NULL` values. Require a non-empty, length-bounded key at every boundary that promises idempotency.

```sql
INSERT INTO items (idempotency_key, name)
VALUES ($1, $2)
ON CONFLICT ON CONSTRAINT items_idempotency_key_key DO UPDATE
SET idempotency_key = EXCLUDED.idempotency_key
WHERE items.name = EXCLUDED.name
RETURNING id, name, creation_date
```

Compare every canonical field that defines the operation, after normalization. The same key and input returns the existing result. The same key with different input returns no row and maps through a repository `.idempotencyConflict` to a use-case conflict. A different key that violates a business constraint remains a normal duplicate error. Never overwrite stored business data with a mismatched retry.

Use compare-and-swap updates for retryable state transitions and stable provider idempotency keys for external side effects such as email or payments. If deleting the result would allow a key to be reused but the product requires longer retention, store outcomes in a dedicated idempotency table.

## State transitions and liveness-scoped uniqueness

Guard a state transition in the `WHERE` clause and let the absent row report the loss:

```sql
UPDATE registrations
SET state = $2, update_date = NOW()
WHERE id = $1 AND state = $3
RETURNING id, state, creation_date, expiration_date
```

Returning no row is how a caller learns it lost the race, atomically and without a separate read.

Carry only the destination state in the command. When each transition has one legal predecessor, derive the guard from the destination on the state enum instead of passing both. Give the initial state no predecessor so it binds as SQL `NULL`, never matches, and fails closed.

For a value that must be unique only while a process is live — one in-flight registration per email — enforce it with a partial unique index over the active states, named `<table>_active_<column>_key`:

```sql
CREATE UNIQUE INDEX registrations_active_email_key
ON registrations (email)
WHERE state IN ('pending', 'verified')
```

Rows in terminal states fall out of the index, so the value frees when the process completes or expires. Scope the predicate to states this service owns the truth about. Map SQLSTATE `23505` on the named index to the matching repository error. Never replace this constraint with a check-then-insert, and never convert the conflict into success by looking up the business value; distinct principals can submit identical business data.

## Database ownership and migrations

### Where a service's data lives

"Database per service" is an ownership rule, not a hardware rule: a service creates, migrates, reads, and writes its own tables, and nothing else touches them. Where those tables physically live is the project's choice, made once for an environment and recorded in the decision record; the skills set no default. The four shapes, from the most isolated down:

| Shape | Isolation | What it costs | When |
| --- | --- | --- | --- |
| **An instance per service** | Complete: its own failure domain, version, maintenance window, backups, point-in-time recovery, and quotas | N clusters to tune, patch, back up, and pay for; per-instance connection limits | Independent scaling or availability targets, a compliance boundary, a team that runs its own database, a managed-database-per-service platform |
| **One instance, a database per service, distinct owners and roles** | Logical: Postgres allows no cross-database query without an FDW; each database has its own owner | One failure domain and maintenance window; point-in-time recovery is cluster-wide; role names are cluster-wide; a noisy neighbour shares buffers and I/O | A small or mid-size workload, a single staging box, a managed cluster billed per instance |
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

Migrations run as the database's owner — on an instance per service the instance's own `POSTGRES_USER` / `POSTGRES_PASSWORD`; on a shared instance the per-service owner created at provisioning, which needs `CREATEROLE`; under a schema per service the schema's owner — and the owner owns every table. Nothing that serves data connects as the owner: Postgres applies no policy to a table's owner. Every other connection is a role a migration creates, one per way of seeing the data:

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

**Which tables.** A table whose rows belong to users. Not a table with no owner — a sign-up list is anyone's to add to and an administrator's to read, which is the use case's `.forbidden` guard. Not credential material looked up *by secret* on anonymous paths (a refresh token or a verification token by digest): a `user_id` policy on those breaks refresh for everyone. The account table is a tenant table even though sign-in finds a row by email before any caller is bound: sign-in runs on the internal role and names the email in its own `WHERE` clause, and the person's own profile runs under the tenant policy ([composition.md](composition.md#a-monolith-serving-http-and-grpc)). The anonymous sign-up that creates a tenant-scoped profile row has no user bound, so the tenant `WITH CHECK` refuses it; it needs a `FOR INSERT` policy of its own for the service role, with no `RETURNING` (below). Not a public catalogue. A table whose rows become public by their own state — a published recipe beside its author's drafts — keeps the owner predicate in `WITH CHECK` and adds only that state to `USING` (`status = 'published' OR user_id = …`); the state is a column of the row, never the caller's role.

**`RETURNING` is a read.** Postgres applies the `SELECT` policy to the row an `INSERT … RETURNING` hands back, and a caller the policy excludes gets `new row violates row-level security policy`. An insert made by a caller who may not read must not `RETURNING`, and the RPC answers with acceptance rather than the record.

**Verify as the roles.** Run against the roles the policies apply to and probe as a user, another user, an administrator, and a process: the tenant role sees one tenant, the internal and worker roles see everything, and the owner proves nothing because the policies are off for it. Check `pg_policies` too, since a renamed setting in code and an unrenamed one in an applied migration fails only at query time.

## Caching

A cache is infrastructure the composition root owns. Core reaches it through a narrow port in the consumer's `Ports/` — `ItemCache` with `get(id:)` and `set(_:ttl:)` — and a `<Module><Technology>` target such as `CatalogValkey` implements it. A cache never holds a decision: a use case reads through it and decides against what it read, and on a miss or an error it reads the database and continues. The TTL is the use case's staleness budget, stated where the use case is composed. A tenant-scoped value is keyed by the tenant as well as the entity. Add a cache only for a measured read the database cannot serve at the required latency.

## Transaction policy

- Every unit of work is `withTransaction`; there is no cheaper entry point.
- Build every repository in a scope from the same supplied connection.
- Never call another service or another module's port from inside `withTransaction` (the one exception is in [core.md](core.md#database-boundary)).
- Never make two service databases participate in one transaction.
- For a multi-service process, use orchestration and explicit failure and retry semantics. Add an outbox only when asynchronous delivery requirements call for it.
