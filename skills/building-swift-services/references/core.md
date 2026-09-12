# Core

## Contents

- Database boundary
- Feature structure
- Ports to other modules
- Logging in use cases

Core is the same target in every shape. A module's Core knows nothing about whether the module ships alone as a service or beside others in a monolith, and nothing about whether its use cases are reached by a route, an RPC, or both.

## Database boundary

Core links `Persistence` from swift-persistence for the transaction boundary, and declares its use cases against it:

```swift
public protocol Database<Scope>: Sendable {
    associatedtype Scope: Sendable

    func withTransaction<T: Sendable>(
        _ operation: @Sendable (Scope) async throws -> T
    ) async throws -> T
}
```

There is one entry point. Every unit of work is a transaction, one read included, because under row-level security the tenant is set on the transaction and the policies read it from there, so a read outside one sees no rows rather than failing. A module with no policies pays a transaction it did not need; a module with them cannot forget. Do not declare a `Database` protocol of the module's own, and do not add a `withConnection`: the shape is the package's so that `<Project>Persistence` and `<Project>Testing` fit every module. See *Scope and database* in [persistence.md](persistence.md).

Do not hold a transaction across a remote call, nor across a call into another module's port. The connection is pooled, so a slow dependency becomes pool exhaustion and one module's latency spike takes this one down with it; and in a monolith the port may become a remote call the day the producer ships alone, so the consumer is written as if it already were.

The narrow exception is rotating a single-use secret: consume the old row, call the dependency, insert the replacement. If the call instead runs after the commit, a dependency outage destroys a credential whose validity that dependency has nothing to do with — a brief blip logs out every caller that happens to rotate during it. Take the exception only when the remote call is one fast read, the transaction is short, the alternative is destroying a caller's credential, and the call carries a deadline well under the pool's wait time. Set that deadline explicitly; without one the pool is bounded by the dependency's worst case.

## Feature structure

Model an entity as an immutable `Equatable, Sendable` struct when domain equality is useful. Keep simple values simple:

```swift
package struct Item: Equatable, Sendable {
    package let id: UUID
    package let name: String
    package let creationDate: Date

    package init(id: UUID, name: String, creationDate: Date) {
        self.id = id
        self.name = name
        self.creationDate = creationDate
    }
}
```

Keep write inputs to repositories as commands. A create command carries only what the caller owns — never the identifier or a persistence-stamped date:

```swift
package struct CreateItemCommand: Sendable {
    package let name: String

    package init(name: String) {
        self.name = name
    }
}
```

The repository protocol expresses persistence operations and throws repository errors:

```swift
package protocol ItemRepository: Sendable {
    func create(_ command: CreateItemCommand) async throws -> Item
    func list() async throws -> [Item]
}
```

Create one narrow scope protocol per use case, naming the repositories it may reach:

```swift
package protocol CreateItemUseCaseScope: Sendable {
    var itemRepository: any ItemRepository { get }
}
```

Keep use-case construction generic over `DatabaseType`, expose it through `XUseCaseProtocol`, and use typed throws:

```swift
package struct CreateItemUseCase<DatabaseType>: CreateItemUseCaseProtocol where DatabaseType: Database, DatabaseType.Scope: CreateItemUseCaseScope {
    private let database: DatabaseType
    private let logger: Logger

    package init(database: DatabaseType, logger: Logger) {
        self.database = database
        self.logger = logger
    }

    package func callAsFunction(
        subject: UserIdentity,
        input: CreateItemUseCaseInput
    ) async throws(CreateItemUseCaseError) -> Item {
        guard subject.role == .admin else {
            logger.warning("Item create refused: not an administrator", metadata: ["userId": "\(subject.userId)"])
            throw .forbidden
        }

        guard !input.name.isEmpty else {
            throw .invalidName
        }

        do {
            let item = try await database.withTransaction { scope in
                let command = CreateItemCommand(name: input.name)
                return try await scope.itemRepository.create(command)
            }
            logger.info("Item created", metadata: ["itemId": "\(item.id)"])
            return item
        } catch ItemRepositoryError.duplicateName {
            logger.warning("Item create rejected: duplicate name", metadata: ["name": "\(input.name)"])
            throw .duplicateName
        } catch {
            logger.warning("Item create failed: unknown error", metadata: ["name": "\(input.name)", "error": "\(String(reflecting: error))"])
            throw .unknown
        }
    }
}
```

The guards are the use case's business rules, stated where they apply; see *Business rules, policies, and adapters* in [architecture.md](architecture.md). Build the command inside the closure and execute it on the next line rather than nesting the construction in the call.

**The identity is in the signature.** A use case names the kind of caller it serves: a public one takes `input:` alone, a user's takes `subject: UserIdentity, input:`, and one another process calls takes `service: ServiceIdentity, input:`. Both identity types come from `<Project>Authentication`, which Core links: `UserIdentity` is the token's claims and `ServiceIdentity` a process's name, and neither carries a key, a signer, or a certificate. Authorization is a guard against that principal at the top of the body, before any I/O, throwing the use case's own `.forbidden`: whether the subject is an administrator, whether the row named in the input is the subject's own. A use case both a user and a process reach has two overloads sharing a private method. The handler's or controller's only job is to insist that the principal is present. See *Authorization lives in the use case* in [identity-and-access.md](identity-and-access.md).

An input carries a value in the type the transport already validated it into: an enum as the enum, a timestamp as a `Date`, so the use case does not re-parse it. The caller's own id arrives in the `subject`, already a `UUID`. A value the wire still carries as a string — a target user's id in a request body — is parsed by the use case, which owns that error.

When a lookup inside a transaction finds nothing, throw the use case's own typed error from inside the closure and rethrow it by type outside — `catch let error as CreateItemUseCaseError { throw error }` — before the named repository errors and the catch-all. Do not return an optional from the closure and unwrap it afterwards, and do not invent a private sentinel error to carry the refusal out of the closure.

Do not pass `Date`, a clock, or a `now` closure into a use case merely to stamp a record. The repository, in practice the database default, owns that persistence concern. The default is therefore no clock in a use case at all. The alternative is a `Clock` injected where the use case *decides* on time — whether a token has expired, whether a grace period has passed — so a test can fix the instant; the clock is then a real seam, and the stored dates still come from the database.

## Ports to other modules

A module that needs another module's behavior declares, in its own Core, the protocol it needs. When the producer's use-case protocol is the right shape, the consumer depends on that shape by re-declaring it, never by importing the producer's Core; more often the consumer needs less, and declares a narrow port naming only the operation and the values it uses:

```swift
package protocol AccountClient: Sendable {
    func account(id: UUID) async throws(AccountClientError) -> Account?
}

package struct Account: Equatable, Sendable {
    package let id: UUID
    package let status: AccountStatus
}
```

The `Account` here is the consumer's own value, carrying only what the consumer reads; it is not the producer's entity and not a generated message. The use case takes the port in its initializer beside the database and calls it outside `withTransaction`:

```swift
package struct CreateItemUseCase<DatabaseType, Accounts>: CreateItemUseCaseProtocol
where DatabaseType: Database, DatabaseType.Scope: CreateItemUseCaseScope, Accounts: AccountClient {
    private let database: DatabaseType
    private let accounts: Accounts
    private let logger: Logger
    // …
}
```

What satisfies the port is the composition root's decision and the root's alone. In a monolith it is the producer module's use case, wrapped in a few lines that convert the producer's entity into the consumer's value; in microservices it is `GRPCAccountClient` in the consumer's GRPC target, over a `GRPCClient` (the consumer adapter in [grpc-and-protos.md](grpc-and-protos.md)). Core cannot tell the two apart, which is the point: the day the producer becomes a service, the consumer's Core does not change. Mock the port in `<Module>CoreTests` exactly as a repository is mocked.

## Logging in use cases

Inject a `Logger` into every use case and log the domain event at the boundary: `info` on the success path (after the write commits, before returning), `warning` on a known refusal (not found, duplicate, rejected), `error` only for a genuine failure. Attach the identifiers that make a line searchable as metadata — `itemId`, `userId`, a correlation id — and never a secret, a token, or a full payload.

The catch-all that maps to `.unknown` always logs, with the cause as `"error": "\(String(reflecting: error))"` beside the identifiers. It is the last place the original error is visible: after it, the caller sees an `internalError` status and nothing else. That is why a pure list or get use case takes a logger too — its only failure branch is the one that would otherwise vanish.

The logger is the last initializer parameter, after every dependency and policy.

This is the `swift-log` facade, which Core may link. The concrete handlers are bootstrapped only in the composition root ([composition.md](composition.md)), which passes its `logger` into each use case's initializer.
