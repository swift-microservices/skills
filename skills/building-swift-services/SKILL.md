---
name: building-swift-services
description: Builds or changes a Swift service package the swift-microservices way, over gRPC, HTTP, or both: the Core, Postgres, GRPC, and executable targets, use cases with the caller in their signature, repositories and prepared statements, database roles and tenant-isolation policies, versioned proto contracts, the composition root with mTLS and bearer or certificate interceptors, and infrastructure-free use-case tests. Use when creating a service, adding a feature, use case, repository, migration, RPC, or test to one, or when editing Package.swift or Sources of a Swift server package.
paths: "Package.swift,Sources/**/*.swift,Tests/**/*.swift"
---

# Building Swift services

One way to build a service: names, target boundaries, folder layout, where each decision lives, and what a test covers. It encodes conventions learned from running such systems on the [swift-microservices](https://github.com/swift-microservices) packages and an organization layer, `<project>-core`. Preserve every convention unless the user explicitly changes it; where the repository already has an established convention that differs, the repository wins for unrelated code.

Designing the boundaries between services, fronting them with an HTTP gateway, orchestrating Temporal workflows, and delivering images are separate skills; this one builds the service.

## Load the references

Read the reference that owns a topic before touching that topic. Each topic has exactly one home.

| Task | Read |
| --- | --- |
| Every task | [architecture.md](references/architecture.md) — target graph, naming grammar, boundary and ownership rules |
| Creating or editing Swift | [swift-style.md](references/swift-style.md) |
| Creating or reshaping the package, manifest, or dependency set | [service-package.md](references/service-package.md) |
| Entities, commands, repositories, scopes, use cases, policies, logging | [core.md](references/core.md) |
| Scopes, statements, transactions, identifiers, idempotency, migrations, the roles, row-level security | [persistence.md](references/persistence.md) |
| Proto contracts, producer and consumer adapters, status mapping | [grpc-and-protos.md](references/grpc-and-protos.md) |
| The identities, tokens, certificates, interceptors, where authorization lives | [identity-and-access.md](references/identity-and-access.md) |
| The executable: configuration, logging bootstrap, clients, server, lifecycle | [composition.md](references/composition.md) |
| The test target, mocks, what a use-case test covers | [testing.md](references/testing.md) |

## Principles

The rules follow from these. When a situation is not covered, decide from the principle.

1. **A service owns a capability and everything about its data.** Its database, identifiers, timestamps, constraints, migrations, contract, and lifecycle. Nothing else reads its tables; nothing else generates its identifiers.
2. **Dependencies point inward, and a third-party SDK earns its own target.** Core links `Persistence`, `<Project>Authentication`, and the `swift-log` facade, never a driver, a gRPC runtime, or a server framework. The adapter translates; the use case decides.
3. **A protocol exists only where substitution is real.** Use cases, repositories, per-use-case scopes, the database, workflow clients, Activity services. Entities, commands, policies, and configuration stay concrete.
4. **The database is the authority on data, not on permission.** It generates identifiers and dates, enforces uniqueness, guards state transitions in the `WHERE` clause, and isolates tenants with policies. Application code never re-implements what a constraint states, and a policy never restates what a use case decides.
5. **Retry safety lives with the owner of the side effect.** An idempotency key is enforced atomically where the write happens, never in memory, a caller, or workflow history.
6. **A credential says who is calling; the use case decides what they may do.** A user is proved by a token and a process by its certificate; roles travel, permissions do not. Identification is shared infrastructure applied per RPC service; the decision is a guard in the use case, against the identity in its signature.
7. **Key material is a file; configuration carries a path.** Keys and certificates are mounted, opened in the composition root, and fail loudly at startup naming the path.
8. **Share the machinery by tag; duplicate the wiring.** The transaction boundary, the interceptors, the identities, and the test doubles come from the packages. Configuration, composition roots, transport-security factories, scopes, and mock repositories are eight lines a service owns.
9. **Translate an error only where the translation adds information.** Let a cause propagate and classify it where the distinction is actionable.
10. **Fail at startup, not at the first request.** Required configuration, key files, and certificates are checked before the process serves.

## Rules

### Package, targets, and naming

1. Name targets `<Service>Core`, `<Service>Postgres`, `<Service>GRPC`, and `<Service>`; add `<Service>Workflows` only with Temporal, and one `<Service><Technology>` leaf per third-party provider SDK. Never `Domain`, `Application`, `Infrastructure`, `Mappings`, or `Adapters`.
2. Use `XUseCase`, `XUseCaseProtocol`, `XUseCaseInput`, `XUseCaseError`, `XUseCaseScope`, `XRepository`, `XRepositoryError`, `XCommand`, `XPolicy`, `XStatement`, `PostgresXRepository`, `Postgres<Service>Scope` (plus `…InternalScope`, `…WorkerScope`), `XPublicService`/`XService`/`XInternalService`.
3. Keep Core independently buildable and free of anything that talks to a network. It links `Persistence`, `<Project>Authentication`, the `swift-log` facade, and focused libraries such as `swift-crypto`; never Postgres, gRPC, protobuf, a logging backend, configuration, a provider SDK, or a server framework.
4. Give every target its direct dependencies in `Package.swift`, and declare a package only when a target links one of its products. Use `package` access between targets; `public` only from separately consumed packages.
5. Depend on organization packages by tagged URL, never `.package(path:)`. Publish and tag the shared package before a service pins it.
6. Take `Database` from swift-persistence, `PostgresDatabase`, `PostgresScope`, `PostgresSettings`, and `PostgresClient.withClient` from swift-persistence-postgres, the interceptors from swift-authentication-grpc, and the identities, `UserSettingsInterceptor`, and the test doubles from `<project>-core`; never redeclare them. Duplicate configuration, transport-security factories, composition roots, scopes, and mock repositories per service.

### Core

7. Model entities and commands as immutable `Sendable` structs. Start with primitive values; introduce a value object only for an established invariant or behavior.
8. Apply a fixed invariant as a `guard` at the top of the use case, before any I/O, throwing the use case's own typed error. Keep a rule that carries product-set values as a plain `XPolicy` struct, never a protocol, never injected. Name a duration `expiration`.
9. Keep every business decision in the use case. A `<Service><Technology>` adapter translates one Core call into one SDK call and back; it never decides whether something applies.
10. Do not inject a concrete collaborator that has no protocol. A policy is not a collaborator: it is a value the composition root builds from configuration, with a `.standard` default for tests.
11. Declare use cases against `Database<Scope>`, generic over `DatabaseType` with `DatabaseType.Scope: XUseCaseScope`. Every unit of work is `withTransaction`; there is no connection-only path. Put the identity in the signature: `input:` for a public use case, `subject: UserIdentity, input:` for a user's, `service: ServiceIdentity, input:` for a process's, with the authorization guard at the top of the body throwing `.forbidden`.
12. Never hold a transaction across a remote call. The sole exception is rotating a single-use secret, with an explicit deadline well under the pool's wait time.
13. Let the database stamp persistence-owned dates with `DEFAULT NOW()`. Do not inject a clock into a use case.
14. Inject a `Logger` into every use case and log the domain event there: `info` on success, `warning` on a known refusal, `error` on a genuine failure, with searchable identifiers and never a secret. The catch-all that maps to `.unknown` logs the cause with `String(reflecting:)`. The `Logger` is the last initializer parameter.

### Persistence

15. Every service owns its whole database: unqualified table names, no service-named schema, one create migration per table, registered explicitly in dependency order.
16. Generate every entity identifier in the owning database with `UUID DEFAULT uuidv7()`. Omit it from create commands and requests; return it after insertion. Never generate another service's identifier.
17. Name stored dates as nouns: `creation_date`, `update_date`, `expiration_date`, and `creationDate` in Swift. Use `Id`, not `ID`.
18. Model a non-identifier secret as one Core value type that mints and digests; persist only the SHA-256 digest; reserve bcrypt for passwords.
19. Make every remotely retryable mutation idempotent where the side effect is owned: a stable namespaced key enforced atomically, returning the prior outcome for the same input and rejecting reuse with different input.
20. Guard every state transition in the `WHERE` clause and treat the absent row as the lost race. Enforce liveness-scoped uniqueness with a partial unique index over the active states.
21. Make `CreateServiceRole` the first migration. Migrations run as the instance's owner; nothing that serves data connects as the owner and no role has `BYPASSRLS`. A tenant service adds `CreateInternalRole`; a service with a worker adds `CreateWorkerRole`; each role has its own secret.
22. Row-level security is tenant isolation and nothing more: every policy is `user_id = NULLIF(current_setting('app.caller_user_id', true), '')::uuid`, with no role in any policy. The tenant reaches the policy as `PostgresSettings.user(_:)`, bound by `UserSettingsInterceptor` after the bearer interceptor on the user service, applied per transaction by the database. The internal and worker roles see every row through `TO "<role>" USING (true)`. A tenant service builds two databases over two scope types, so a use case declares which it runs on and the compiler refuses the other.

### Contracts and transport

23. Keep canonical `.proto` files only in `<project>-protos`, nested by organization, service, and version, starting at `v1`. Split every contract by audience: `<Entity>PublicService`, `<Entity>Service`, `<Entity>InternalService`.
24. Put protobuf conversions in the feature's `Protobuf/` directory as `X+Protobuf.swift`; perform transport validation in the conversion initializer. Keep generated messages out of Core.
25. Map typed use-case failures to stable status codes in the producer; map them back to local errors in the consumer. Never let `PSQLError`, SQLSTATE, or `RPCError` reach Core. Format UUIDs lowercased on the wire; refuse an unrecognized enum value.

### Identity and access

26. One issuer, asymmetric keys: the authenticating service alone builds `JWTIssuer<UserIdentity>` from its private key; every service builds `JWTAuthenticator<UserIdentity>` from the public key. Never a shared HMAC secret.
27. `UserIdentity` is the token's payload: `userId` keyed to `sub`, `role`, `iss`, `iat`, `exp`. `UserRole` is an open string with `.user` and `.admin`; there is no `service` role. A process is `ServiceIdentity`, named by the `spiffe://<project>/<process>` URI SAN of the certificate it already presents, read by `ServiceAuthenticator`.
28. Identify a caller and require one as separate steps. The interceptors pass an absent credential through anonymously and refuse a present, invalid one; requiring is a private guard in the handler reading `ServiceContext.current?.user` or `.service`. Absent is `unauthenticated`; a present caller the use case refuses is `permissionDenied`.
29. Apply `BearerAuthenticationInterceptor` then `UserSettingsInterceptor` to the user service, `CertificateAuthenticationInterceptor(authenticator: ServiceAuthenticator())` to the internal service, nothing to the public one, each with `.apply(_, to: .services([descriptor]))`. Propagate a user by forwarding the token unchanged with `BearerPropagationInterceptor<UserIdentity>` on the client's user-service descriptors. A client that speaks as the process carries no interceptor.
30. Never declare a `@TaskLocal` for a caller. Pass `.user` and `.service` metadata providers to the logging bootstrap.

### Composition

31. Name the executable after the service and make it the package's one product. `serve` is the default subcommand and carries `--migrate-database`; a Temporal worker is `worker run` on the same executable.
32. Construct every long-lived client, server, and worker once in the composition root, under `// MARK:` sections in the order Configuration, Logging, Infrastructure, Composition, gRPC, Lifecycle, owned by one `ServiceGroup` with graceful shutdown.
33. Read configuration with `ConfigReader` scoped by concern. Require infrastructure values and secrets; default only listen address, port, log level, and the service's own identity. Give each configuration an `init(config:)` extension in the executable's `Configuration` folder, opening key material by path.
34. Mutually authenticate every internal gRPC connection through two `static func mTLS(config:)` factories on grpc-swift's transport-security types, in each service's `Configuration` folder. Bootstrap logging inline: stdout plus in-process shipping, the service name as label.

### Tests

35. Give every service a `<Service>CoreTests` target on swift-testing, depending on Core, `swift-log`, `<Project>Authentication`, and `<Project>Testing`. Plain imports; needing `@testable` signals a wrong access level.
36. Test use cases against an actor mock repository and `MockDatabase` through a scoped `withDatabase` helper in `Mocks/`; build subjects with `makeSubject(role:)`. Fixed dates, never `Date()`.
37. Cover the success path of each overload, every guard including the authorization guard asserting the repository was never reached, and every repository-error-to-use-case-error translation. Use-case tests bind no `ServiceContext`; `swift test` needs no infrastructure.

### Working in an existing service

38. Preserve behavior, naming, and unrelated user changes. Never infer permission to drop tables, discard data, or delete a migration; finish the non-destructive work and surface the decision.

## Workflow

Copy this checklist and check items off as you go:

```
Build a service:
- [ ] 1. Package: swift package init --type executable, reshape to <Service>Core, <Service>Postgres, <Service>GRPC, <Service>; provider and Workflows targets only when needed
- [ ] 2. Core: entities, commands, repositories, scope protocols, use-case contracts with the identity in the signature, typed errors with .forbidden, policies, use cases with their guards
- [ ] 3. Tests: <Service>CoreTests with mock repositories and scopes, withDatabase over MockDatabase, makeSubject, the guard/translation/success matrix
- [ ] 4. Postgres: one scope per role, statements, repositories, error translation, CreateServiceRole first, the other roles, ordered migrations, tenant policies where rows belong to users
- [ ] 5. GRPC: one conformance per audience, feature-local Protobuf/ conversions, each handler insisting on its identity
- [ ] 6. Serve: configuration, logging with the metadata providers, boot migrations behind --migrate-database, one database per role, mTLS factories, the interceptors per proto service, lifecycle
- [ ] 7. swift build, swift test, then exercise the contract, the identity paths, and the roles
```

For a focused change, load only the references the change touches and preserve the established architecture.

## Completion gates

Do not call work complete until every applicable gate passes.

- Every package builds in Swift 6 language mode with `swift build`, and `<Service>CoreTests` passes with `swift test` and no infrastructure.
- Generated protobuf types appear only in the GRPC target and consumer adapters; Postgres types only in the Postgres target and the executable.
- Every use case runs through `withTransaction`; no service declares a `Database`, `PostgresDatabase`, `PostgresScope`, `MockDatabase`, or `PostgresClient.withClient` of its own.
- No `<Service>Core`, `<Service>Postgres`, or `<Service>GRPC` target links a driver, grpc-swift, or a server framework it does not own.
- Every entity identifier is database-generated and absent from create inputs; every retryable mutation has owner-enforced idempotency.
- The first migration is `CreateServiceRole`; serving connects as the service and internal roles, only the boot-migration client as the owner, and no role has `BYPASSRLS`.
- Every policy is a tenant predicate on `app.caller_user_id` with no role in it; the user service carries `UserSettingsInterceptor` after the bearer interceptor; the policies were exercised as each role with a user, another user, an administrator, and a process.
- Every contract is split by audience with the bearer interceptor on the user service, the certificate interceptor on the internal service, and nothing on the public one.
- Every use case names its identity in its signature and decides authorization in its body; no handler, interceptor, or policy decides it.
- The bound user and process appear as `user_id` and `service_name` on every log line of a request.
- Every long-lived client, server, and worker is in a `ServiceGroup` with graceful shutdown.

If a gate requires an unresolved product, consistency, security, or data-migration decision, stop at the safe boundary and request that decision rather than inventing behavior.
