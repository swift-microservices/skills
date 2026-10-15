# Postgres persistence

Keep every Postgres type in the module's `<Module>Postgres` target (`<Service>Postgres` when the module is a service), except executable configuration and client construction. The rules are the same in a monolith and in a service; what differs is how many modules share one database, which [One database, many modules](migrations-and-rls.md#one-database-many-modules) covers.

## Contents

- [Scope and database](#scope-and-database)
- [Repositories and statements](#repositories-and-statements)
- [Identifiers, dates, and secrets](#identifiers-dates-and-secrets)
- [Idempotent writes](#idempotent-writes)
- [State transitions and liveness-scoped uniqueness](#state-transitions-and-liveness-scoped-uniqueness)
- [Database ownership and migrations](migrations-and-rls.md#database-ownership-and-migrations)
  - [Where a service's data lives](migrations-and-rls.md#where-a-services-data-lives)
  - [Tables and migrations](migrations-and-rls.md#tables-and-migrations)
  - [The migration list](migrations-and-rls.md#the-migration-list)
  - [Polyglot persistence](migrations-and-rls.md#polyglot-persistence)
- [One database, many modules](migrations-and-rls.md#one-database-many-modules)
- [The roles](migrations-and-rls.md#the-roles)
- [Row-level security](migrations-and-rls.md#row-level-security)
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

At the start of each transaction the database applies `PostgresSettings`: its constant ones, such as `application_name`, merged with whatever the task's `OperationContext` carries. Each becomes `set_config(name, value, true)`, transaction-local, so a pooled connection carries nothing to its next borrower. That is how the tenant reaches the policies ([Row-level security](migrations-and-rls.md#row-level-security)).

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

## Caching

A cache is infrastructure the composition root owns. Core reaches it through a narrow port in the consumer's `Ports/` — `ItemCache` with `get(id:)` and `set(_:ttl:)` — and a `<Module><Technology>` target such as `CatalogValkey` implements it. A cache never holds a decision: a use case reads through it and decides against what it read, and on a miss or an error it reads the database and continues. The TTL is the use case's staleness budget, stated where the use case is composed. A tenant-scoped value is keyed by the tenant as well as the entity. Add a cache only for a measured read the database cannot serve at the required latency.

## Transaction policy

- Every unit of work is `withTransaction`; there is no cheaper entry point.
- Build every repository in a scope from the same supplied connection.
- Never call another service or another module's port from inside `withTransaction` (the one exception is in [core.md](core.md#database-boundary)).
- Never make two service databases participate in one transaction.
- For a multi-service process, use orchestration and explicit failure and retry semantics. Add an outbox only when asynchronous delivery requirements call for it.
