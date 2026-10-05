# Public API

## Contents

- Access and imports
- Small, protocol-shaped surfaces
- Errors
- Scoped callbacks and isolation
- ServiceContext keys
- Logging, configuration, and lifecycle
- Documentation
- What a library never does

A library's public API is a contract every consumer compiles against and every release must honor. Keep it as small as the concept, document every declaration, and make each guarantee one its tests prove.

## Access and imports

- `public` only for what consumers use; everything else `internal` or `private`. A library has no `package`-access consumers outside itself.
- Plain imports are internal under `InternalImportsByDefault`. Write `public import` exactly where an imported type appears in public API (`public import ServiceContextModule` beside a `ServiceContextKey`, `public import JWTKit` beside a `JWTPayload` constraint); `public import` does not re-export names, so a consumer still imports the modules it names. Under the conditional Foundation import, both branches carry the same access.
- Module-qualify a name that collides with the framework's own: the Vapor binding writes `Authentication.Authenticator` because Vapor has one too.
- Make every public type and protocol `Sendable` where it is meaningful; a public reference type with mutable state is an actor or holds it behind a `Mutex`.

## Small, protocol-shaped surfaces

Use a protocol with primary associated types where consumers substitute implementations, so a consumer can write `any Authenticator<String, UserIdentity>` or `some Database<Scope>`:

```swift
public protocol Authenticator<Credential, Identity>: Sendable {
    associatedtype Credential: Sendable
    associatedtype Identity: Sendable

    func authenticate(_ credential: Credential) async throws -> Identity
}
```

- A requirement returns what it promises or throws; do not return an optional to mean "declined". An authenticator returns an identity or throws, and a call with no credential never reaches it — the binding passes it through anonymously.
- Make a concrete type generic over the consumer's own type where the library does not know it: `JWTAuthenticator<Payload: JWTPayload>`, `PostgresDatabase<Scope: PostgresScope>`, `BearerPropagationInterceptor<Identity>`. The library never names an organization's claims or roles.
- Take a dependency as a protocol existential at the initializer (`authenticator: any Authenticator<String, Identity>`) when the type stores it, and as a generic when the call is hot and the type is not stored.
- A designated initializer takes the values the type needs and nothing that has a sensible default is required; conveniences that bind an organization's choices (an EdDSA key over `init(keys:)`) belong to the organization layer as extensions with a `where` clause.
- Constants and helpers that every consumer would otherwise reimplement identically belong in the library (`Metadata.bearer`, `PostgresSettings` merging); a choice two consumers would make differently does not.

## Errors

Let an error a caller handles reach it unchanged: `PostgresDatabase.withTransaction` unwraps PostgresNIO's `PostgresTransactionError` and rethrows the error that caused the rollback, so a use case catches the domain error its repository threw. Translate an error only where the translation adds information and the boundary demands a type: a gRPC interceptor answers `RPCError(code: .unauthenticated)`, a Hummingbird middleware `HTTPError(.unauthorized)`, a Vapor middleware `Abort(.unauthorized)`, each with a stable message that discloses nothing. Use typed throws where the error set is closed and part of the contract; a library that forwards a consumer's or a driver's errors throws `any Error`.

## Scoped callbacks and isolation

An API that runs a consumer's closure inside a scope it owns — a transaction, a client's lifetime, a runner — keeps the closure plain, nonescaping, and caller-isolated:

```swift
func withTransaction<T: Sendable>(
    _ operation: (Scope) async throws -> T
) async throws -> T
```

Under `NonisolatedNonsendingByDefault` the closure inherits the caller's isolation, so an actor can mutate its own non-Sendable state inside it. It carries neither `@Sendable` nor `@concurrent`; the requirement, every implementation, and every test double agree. When the implementation forwards to a dependency with an isolated parameter, preserve the caller explicitly, `client.withTransaction(logger: logger, isolation: #isolation) { … }`; a static entry point takes `isolation: isolated (any Actor)? = #isolation` itself:

```swift
public static func withClient<T: Sendable>(
    configuration: PostgresClient.Configuration,
    isolation: isolated (any Actor)? = #isolation,
    logger: Logger,
    operation: (PostgresClient) async throws -> T
) async throws -> T
```

Document what the isolation does not do: other work on an actor may run while the closure is suspended, a rollback does not undo in-memory mutations, and the scope and anything built on it are valid only during the closure; `Sendable` does not extend a transaction's lifetime. Prove the contract with the [isolation contract tests](testing.md#isolation-contract-tests).

Where a framework protocol requires `@concurrent` on a continuation (`next` in a GRPCCore interceptor or a Hummingbird `RouterMiddleware`, an OpenAPI `ClientMiddleware`), match the requirement exactly; that is the one place `@concurrent` appears in a library's public API.

## ServiceContext keys

A value that travels with a task, such as a bound principal or the settings a transaction applies, is a `ServiceContextKey` the library declares, with a stable `nameOverride` and a typed accessor:

```swift
public enum PostgresSettingsKey: ServiceContextKey {
    public typealias Value = PostgresSettings
    public static let nameOverride: String? = "postgres-settings"
}

extension ServiceContext {
    public var postgresSettings: PostgresSettings? {
        get { self[PostgresSettingsKey.self] }
        set { self[PostgresSettingsKey.self] = newValue }
    }
}
```

Never declare a `@TaskLocal` of the library's own: `ServiceContext` is the one carrier, it crosses the frameworks' boundaries, and the logging metadata providers read it. A binding sets the value with `ServiceContext.withValue` around the continuation and keeps any parallel state (a Hummingbird context's `identity`, Vapor's `request.auth` and `request.serviceContext`) in step with it. The organization layer adds named accessors over generic keys (`ServiceContext.user` over `PrincipalKey<UserIdentity, String>`).

## Logging, configuration, and lifecycle

- **Logging.** Accept a `Logger` from the caller as the last parameter of every initializer that needs one, with no default; a trailing operation closure is the only parameter that follows it. Log through the swift-log facade. Never bootstrap the logging system, construct a handler, or create a logger from a hard-coded label inside the library.
- **Configuration.** A library may offer a convenience `init(config: ConfigReader)` that reads documented relative keys and delegates to its typed initializer; the application chooses providers, scopes, and defaults. A library never constructs `EnvironmentVariablesProvider`, hard-codes an application's mount paths, or requires its own configuration package. Prefer adopting an upstream native reader over wrapping it. See the building skill's [configuration reference](../../building-swift-services/references/configuration.md) for the application side.
- **Lifecycle.** A long-lived runnable type conforms to ServiceLifecycle's `Service` so the application owns it in its `ServiceGroup`; the library never starts a detached task to keep itself alive, never installs signal handlers, and never owns a global singleton. A scoped convenience that starts and cancels a client within a closure (`withClient`) is the alternative for short-lived use.

## Documentation

Every public declaration has a `///` comment that begins with a one-line summary; the formatter does not enforce this, review does. The target has a DocC catalog, `Sources/<Module>/Documentation.docc/<Module>.md` with articles for the concepts a symbol comment cannot hold (the transaction and scope contract, how a binding is composed), and it builds without warnings. A code sample in a comment or an article compiles against the current API. Document behavior that is not in the signature: what happens with no credential, which error reaches the caller, what is and is not isolated, what the library deliberately does not do.

## What a library never does

- Decide authorization, read an organization's claims, or name a role; the owning use case and the organization layer do.
- Run statements outside its unit of work (there is no `withConnection` beside `withTransaction`), or offer a second path that skips what the first guarantees.
- Read environment variables, open files at fixed paths, or configure transport security; composition roots do.
- Mint or forward credentials on its own initiative; a propagation interceptor forwards the original credential of the principal already bound.
- Hide a breaking change in a patch, or keep a deprecated path alive past the release that replaces it without saying so in the release notes.
