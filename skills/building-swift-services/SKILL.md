---
name: building-swift-services
description: Builds or changes a Swift server package the swift-microservices way, as a modular monolith or as a microservice, over HTTP, gRPC, or both. Modules with Core, Postgres, HTTP, and GRPC targets, use cases with the caller in their signature, repositories and prepared statements, database roles and tenant-isolation policies, versioned proto contracts, an OpenAPI document generating types, bearer middleware and interceptors, a composition root with mTLS, an HTTP gateway in front of gRPC services, and infrastructure-free use-case tests. Use when creating a monolith, a module, a service, or a gateway, adding a feature, use case, repository, migration, route, RPC, or test to one, or when editing Package.swift, Sources, or an openapi.yaml of a Swift server package.
paths: "Package.swift,Sources/**/*.swift,Sources/**/openapi.yaml,Tests/**/*.swift"
---

# Building Swift services

One way to build a server package: the module grammar, target boundaries, folder layout, where each decision lives, and what a test covers. It encodes conventions learned from running such systems on the [swift-microservices](https://github.com/swift-microservices) packages and an organization layer, `<project>-core`. Preserve every convention unless the user explicitly changes it; where the repository already has an established convention that differs, the repository wins for unrelated code.

Two choices are made before the first file and never again per file: the **deployment shape** (a monolith: one package, one executable, every module inside; or microservices: one package per module, each with its own executable and database) and the **transport** (HTTP, gRPC, or both). Every combination is valid, and a module is built the same way in every one of them. Choosing the shape, orchestrating Temporal workflows, and delivering images are separate skills; this one builds the package.

Rules in this skill are conventions the packages and the shared code shape depend on; keep them unless the user changes the vocabulary. Where a rule says *default* and names an alternative, that is a project choice: take the default unless the project's decision record says otherwise, and never switch it per file.

## Load the references

Read the reference that owns a topic before touching that topic. Each topic has exactly one home.

| Task | Read |
| --- | --- |
| Every task | [architecture.md](references/architecture.md) — the two shapes, the module grammar, target graphs, movability, boundary and ownership rules |
| Creating or editing Swift | [swift-style.md](references/swift-style.md) |
| Anything touching tasks, actors, `Sendable`, isolation, or a data-race diagnostic | the `swift-concurrency` skill, [AvdLee/Swift-Concurrency-Agent-Skill](https://github.com/AvdLee/Swift-Concurrency-Agent-Skill) — install it; this skill does not restate it |
| Creating or reshaping a package, manifest, or dependency set | [service-package.md](references/service-package.md) — monolith, service, and gateway manifests |
| Entities, commands, repositories, scopes, use cases, policies, logging, cross-module protocols | [core.md](references/core.md) |
| Scopes, statements, transactions, identifiers, idempotency, migrations, the roles, row-level security, one database for many modules | [persistence.md](references/persistence.md) |
| Proto contracts, producer and consumer adapters, status mapping | [grpc-and-protos.md](references/grpc-and-protos.md) |
| The HTTP surface | [http.md](references/http.md) — the OpenAPI document, contexts, tiers, middleware, controllers over use cases or gRPC stubs, conversions, problem details, the Vapor alternative |
| The identities, tokens, certificates, interceptors and middleware, validation at every process, where authorization lives | [identity-and-access.md](references/identity-and-access.md) |
| The executable: configuration, logging bootstrap, clients, servers, the monolith, service, worker, and gateway roots | [composition.md](references/composition.md) |
| The test target, mocks, what a use-case test covers, transport tests | [testing.md](references/testing.md) |

## Principles

The rules follow from these. When a situation is not covered, decide from the principle.

1. **A module owns a capability and everything about its data.** Its tables, identifiers, timestamps, constraints, migrations, contract, and use cases. Nothing else reads its tables; nothing else generates its identifiers. In microservices a module is a service; in a monolith it is a set of targets in one package, and the ownership rules are the same, kept by review rather than by a network.
2. **The shape and the transport are wiring, not architecture.** A module has the same Core and Postgres targets whether it ships alone or beside ten others, and the same use cases whether they are reached by a route, an RPC, or both. Only the composition root knows which.
3. **A module is movable.** Its transport targets are its own and it imports no other module. Turning a module into a service moves its targets into their own package and swaps what the composition root injects; nothing inside the module changes.
4. **Dependencies point inward, and a third-party SDK earns its own target.** Core links `Persistence`, `<Project>Authentication`, and the `swift-log` facade, never a driver, a gRPC runtime, or a server framework. The adapter translates; the use case decides.
5. **A protocol exists only where substitution is real.** Use cases, repositories, per-use-case scopes, the database, workflow clients, Activity services, and the port one module needs from another. Entities, commands, policies, and configuration stay concrete.
6. **The database is the authority on data, not on permission.** It generates identifiers and dates, enforces uniqueness, guards state transitions in the `WHERE` clause, and isolates tenants with policies. Application code never re-implements what a constraint states, and a policy never restates what a use case decides.
7. **Retry safety lives with the owner of the side effect.** An idempotency key is enforced atomically where the write happens, never in memory, a caller, or workflow history.
8. **A credential says who is calling; the use case decides what they may do.** A user is proved by a token and a process by its certificate; roles travel, permissions do not. Identification is shared infrastructure applied per RPC service or router tier; the decision is a guard in the use case, against the identity in its signature.
9. **Every process verifies what it receives.** A token is checked with the issuer's public key by each process it reaches and crosses a process boundary only as the original credential. A monolith verifies once because it crosses none.
10. **Key material is a file; configuration carries a path.** Keys and certificates are mounted, opened in the composition root, and fail loudly at startup naming the path.
11. **Share the machinery by tag; duplicate the wiring.** The transaction boundary, the interceptors and middleware, the identities, and the test doubles come from the packages. Configuration, composition roots, transport-security factories, scopes, and mock repositories are eight lines a package owns.
12. **Translate an error only where the translation adds information.** Let a cause propagate and classify it where the distinction is actionable.
13. **Fail at startup, not at the first request.** Required configuration, key files, and certificates are checked before the process serves.
14. **Concurrency is checked by the compiler, not by convention.** Every package builds in Swift 6 language mode with strict concurrency and no diagnostic silenced to get there. A server holds one process open for every caller at once, so a data race here is a production incident rather than a flicker, and the language is the only thing that can rule one out ahead of time.

## Rules

### Shape, package, targets, and naming

1. Choose the shape once: a monolith is one package `<organization>-<project>` with one executable target `<Project>`; a microservice is one package `<organization>-<service>` with one executable target `<Service>`. An HTTP gateway in front of services is a package `<organization>-api` with exactly two targets, `API` and `<Project>`, and no Core or Postgres. Never call the monolith a stepping stone; it is the smallest shape that fits.
2. Name a module's targets `<Module>Core`, `<Module>Postgres`, `<Module>HTTP`, and `<Module>GRPC`; add `<Module>Workflows` only with Temporal, and one `<Module><Technology>` leaf per third-party provider SDK. In a service the module name is the service name, so the targets read `<Service>Core`, `<Service>GRPC`, and so on. Never `Domain`, `Application`, `Infrastructure`, `Mappings`, or `Adapters`.
3. Give every module the transport targets the shape serves and no other: an HTTP-only monolith has `<Module>HTTP` per module and no GRPC target; a gRPC-only one the reverse; a monolith serving both has both. Transport targets are per module in every shape, so a gRPC monolith registers `CatalogGRPC`'s and `UsersGRPC`'s services on one `GRPCServer` and an HTTP monolith mounts `CatalogHTTP`'s and `UsersHTTP`'s controllers on one router.
4. A module never imports another module's Core, Postgres, HTTP, or GRPC target. Only the executable sees more than one module. Where a module needs another's behavior, its Core declares the use-case protocol or narrow client port it needs, and the composition root injects the producer module's use case (a monolith) or a gRPC client adapter conforming to the same protocol (microservices).
5. In a monolith, put the request contexts, the error middleware, and the problem types that every `<Module>HTTP` shares in one `<Project>HTTP` target that each of them links; a service's single `<Service>HTTP` holds them itself, and a gateway's `API` does.
6. Use `XUseCase`, `XUseCaseProtocol`, `XUseCaseInput`, `XUseCaseError`, `XUseCaseScope`, `XRepository`, `XRepositoryError`, `XCommand`, `XPolicy`, `XStatement`, `PostgresXRepository`, `Postgres<Module>Scope` (plus `…InternalScope`, `…WorkerScope`), `<Module>Migrations`, `XPublicService`/`XService`/`XInternalService`, `XController`.
7. Keep Core independently buildable and free of anything that talks to a network. It links `Persistence`, `<Project>Authentication`, the `swift-log` facade, and focused libraries such as `swift-crypto`; never Postgres, gRPC, protobuf, Hummingbird, Vapor, a logging backend, configuration, or a provider SDK.
8. Give every target its direct dependencies in `Package.swift`, and declare a package only when a target links one of its products. Use `package` access between targets; `public` only from separately consumed packages.
9. Depend on organization packages by tagged URL, never `.package(path:)`. Publish and tag the shared package before a package pins it.
10. Take `Database` from swift-persistence, `PostgresDatabase`, `PostgresScope`, `PostgresSettings`, and `PostgresClient.withClient` from swift-persistence-postgres, the interceptors from swift-authentication-grpc, the bearer middleware from swift-authentication-hummingbird or swift-authentication-vapor, and the identities, `UserSettingsInterceptor`, `UserSettingsMiddleware`, and the test doubles from `<project>-core`; never redeclare them. Duplicate configuration, transport-security factories, composition roots, scopes, migrations lists, and mock repositories per package.

### Core

11. Model entities and commands as immutable `Sendable` structs. Start with primitive values; introduce a value object only for an established invariant or behavior.
12. Follow the Swift Concurrency guidelines, which are the `swift-concurrency` skill's ([AvdLee/Swift-Concurrency-Agent-Skill](https://github.com/AvdLee/Swift-Concurrency-Agent-Skill)); load it for any task that touches tasks, actors, isolation, `Sendable`, or a data-race diagnostic. It is not optional and this skill does not repeat it. What is settled here regardless: Swift 6 language mode in every package with strict concurrency on; an actor, or `Mutex`, for shared mutable state, never a semaphore or an ad-hoc lock in an async context; `@unchecked Sendable` only with a comment stating what guarantees the safety, never to quiet a diagnostic; structured concurrency and a task group over a detached task; one `ServiceGroup` owning every long-lived task; and cancellation honoured in anything long-running, which on a server means every worker loop and every stream.
12. Apply a fixed invariant as a `guard` at the top of the use case, before any I/O, throwing the use case's own typed error. Keep a rule that carries product-set values as a plain `XPolicy` struct, never a protocol, never injected. Name a duration `expiration`.
13. Keep every business decision in the use case. A `<Module><Technology>` adapter translates one Core call into one SDK call and back; it never decides whether something applies.
14. Do not inject a concrete collaborator that has no protocol. A policy is not a collaborator: it is a value the composition root builds from configuration, with a `.standard` default for tests.
15. Declare use cases against `Database<Scope>`, generic over `DatabaseType` with `DatabaseType.Scope: XUseCaseScope`. Every unit of work is `withTransaction`; there is no connection-only path. Put the identity in the signature: `input:` for a public use case, `subject: UserIdentity, input:` for a user's, `service: ServiceIdentity, input:` for a process's, with the authorization guard at the top of the body throwing `.forbidden`.
16. Never hold a transaction across a remote call, and in a monolith never across a call into another module's use case. The sole exception is rotating a single-use secret, with an explicit deadline well under the pool's wait time.
17. Persistence-owned dates are stamped by the database with `DEFAULT NOW()`, so a use case never carries "now" for a creation or update date. Default: no clock in a use case. Alternative: inject a `Clock` only where a use case decides on time, an expiry check or a grace period, so a test can fix it; never to stamp a stored date.
18. Inject a `Logger` into every use case and log the domain event there: `info` on success, `warning` on a known refusal, `error` on a genuine failure, with searchable identifiers and never a secret. The catch-all that maps to `.unknown` logs the cause with `String(reflecting:)`. The `Logger` is the last initializer parameter.

### Persistence

19. A service owns its whole database; a monolith owns one database in which each module owns its tables. In both, unqualified table names, no module- or service-named schema, one create migration per table, and no query, join, or foreign key across a module boundary. Where that database lives is the deployment's choice, recorded once: an instance per service, one instance with a database and owner per service (default), or a schema per service; the ownership rule holds in all three, and shared tables are never one of them. Postgres is the default store; a module whose measured access pattern needs another store owns it the same way, through a Core port and a driver or adapter target, keeps one store as the truth for each entity, and never spans two stores with one transaction.
20. The owning database generates every entity identifier; omit it from create commands and requests and return it after insertion. Never generate another module's identifier. Default: `UUID DEFAULT uuidv7()` on Postgres 18. Alternative: `gen_random_uuid()` on an older instance, at the cost of index locality.
21. Name stored dates as nouns: `creation_date`, `update_date`, `expiration_date`, and `creationDate` in Swift. Use `Id`, not `ID`.
22. Model a non-identifier secret as one Core value type that mints and digests; persist only the SHA-256 digest; reserve bcrypt for passwords.
23. Make every remotely retryable mutation idempotent where the side effect is owned: a stable namespaced key enforced atomically, returning the prior outcome for the same input and rejecting reuse with different input.
24. Guard every state transition in the `WHERE` clause and treat the absent row as the lost race. Enforce liveness-scoped uniqueness with a partial unique index over the active states.
25. Migrations run as the instance's owner; nothing that serves data connects as the owner; no role has `BYPASSRLS`; and a tenant-scoped role and an unscoped internal role are distinct roles with their own secrets, so which client a use case is built over decides what it can see. Roles belong to the process, so a package has one set. Default naming: `<name>_service` from `CreateServiceRole`, the first migration; `<name>_internal` from `CreateInternalRole` when any module has tenant tables; `<name>_worker` from `CreateWorkerRole` with Temporal, where `<name>` is the service or the project. Alternative: any naming, provided the role migrations precede the tables and the migration client is the only owner connection.
26. Each `<Module>Postgres` exposes its table and policy migrations as one ordered list, `<Module>Migrations.migrations(internalRole:)`. The executable's `Migrations.swift` adds the role migrations first, then every module's list in module dependency order.
27. Row-level security is the default for tables whose rows belong to end users in a multi-user application, and its main concern is tenant isolation: a policy confines a request to the caller's rows, `user_id = NULLIF(current_setting('app.caller_user_id', true), '')::uuid`, while what the caller may do stays in the use case. The tenant reaches the policy as `PostgresSettings.user(_:)`, bound by `UserSettingsInterceptor` after the bearer interceptor on gRPC and by `UserSettingsMiddleware` after the bearer middleware on HTTP, applied per transaction by the database. The internal and worker roles see every row through `TO "<role>" USING (true)`. A module with tenant tables has two scope types, `Postgres<Module>Scope` and `Postgres<Module>InternalScope`, and a use case declares which it runs on so the compiler refuses the other. Alternative: a single-tenant application, an internal tool, a deployment per customer, or a module whose tables are not user-owned has no policies, one service role, one scope, and no settings interceptor or middleware; that is a decision recorded once, not an omission. Where the tenant is an organization rather than a user, the setting and the predicate name that id instead, and the org layer's settings helper carries it.
28. A cache is infrastructure the composition root owns, reached from Core through a narrow `<Entity>Cache` port in the consumer's `Ports/` and implemented in a `<Module><Technology>` target such as `<Module>Valkey`. It never holds a decision, never replaces the database as the source of truth, carries a TTL chosen from the use case's staleness budget, and stores nothing tenant-scoped under a key that omits the tenant. Add one only for a measured read the database cannot serve.

### gRPC contracts and transport

29. Canonical `.proto` files have one home, nested by organization, module, and version, starting at `v1` and evolving it additively. Split every contract by audience: `<Entity>PublicService`, `<Entity>Service`, `<Entity>InternalService`. Default in microservices: the tagged `<project>-protos` package, because two or more packages consume them. Alternative in a gRPC monolith: `Sources/<Module>GRPC/Protos/` with the generator plugin in the same package, because one package consumes them; they move to `<project>-protos` the day a second package does. A gRPC monolith keeps the same audience split; its internal services exist for its own workers and for the day a module ships alone.
30. Put protobuf conversions in the feature's `Protobuf/` directory as `X+Protobuf.swift`; perform transport validation in the conversion initializer. Keep generated messages out of Core.
31. Map typed use-case failures to stable status codes in the producer; map them back to local errors in the consumer. Never let `PSQLError`, SQLSTATE, or `RPCError` reach Core. Format UUIDs lowercased on the wire; refuse an unrecognized enum value.

### HTTP transport

32. One routing mechanism and one contract: keep `openapi.yaml` beside `openapi-generator-config.yaml` in the HTTP target that serves it, with `package` access. Default: generate `types` only and register routes by hand on the router, for a project that wants the framework's own APIs (Hummingbird's `RequestContext` chain, route groups, and middleware; Vapor's route collections and `req.auth`) to carry the tiers. Alternative: generate `server` too and mount the stubs through the framework's transport, `OpenAPIHummingbird` (swift-openapi-hummingbird) or `OpenAPIVapor` (swift-openapi-vapor), when a team wants the compiler to hold the document and the handlers together, at the cost of tiering by middleware on the generated transport instead of by route group. Chosen once per project. A monolith has one document per `<Module>HTTP`, which is that module's contract.
33. Chain `BasicRequestContext` → `IdentityRequestContext` → `AdminRequestContext`, carrying `coreContext` across. Register routes in three tiers: session-issuing and health routes outside any authenticating middleware; an identifying tier under `BearerAuthenticationMiddleware<IdentityRequestContext>(authenticator:)` that admits anonymous requests, followed by `UserSettingsMiddleware` wherever a module has tenant tables; a requiring tier under `IsAuthenticatedMiddleware`. Never a path exception inside a middleware; never collapse the identifying and requiring tiers.
34. Give administrative routes the same path as the resource they act on, gated by `group(context: AdminRequestContext.self)` at the verb, never an `/admin` prefix. Keep verb-shaped routes verb-shaped: sessions, webhooks, and callbacks are workflows, not resources.
35. One `XController` per resource, with registration methods named for the tier they mount into. In a module the controller holds the module's use-case protocols and converts in `Schemas/Requests/` and `Schemas/Responses/` as `X+Schema.swift`; in a gateway it holds generated gRPC client protocols, one per proto service, and converts as `X+RPC.swift`. A conversion throws on a malformed value; it never drops one with `compactMap`.
36. Answer every failure as RFC 9457 problem details with `application/problem+json`. A module maps its use-case errors to statuses in the controller; a gateway maps `RPCError` by code — `invalidArgument` 400, `unauthenticated` 401, `permissionDenied` 403, `notFound` 404, `alreadyExists` 409, `resourceExhausted` 429, `unimplemented` 501, `unavailable` 503, `deadlineExceeded` 504 — and reserves 500 for a failure it cannot classify, logged with its cause.
37. On Vapor 4, the middleware is swift-authentication-vapor's `BearerAuthenticationMiddleware` over an `Authenticatable` identity, the requiring tier is `guardMiddleware()`, the admin check is a route-group middleware, the principal is read from `request.serviceContext`, and outgoing calls and use cases run under `ServiceContext.withValue(req.serviceContext)`. A `<Module>HTTP` on Vapor is a `RouteCollection` per controller, and the Vapor form of `UserSettingsMiddleware` writes the tenant setting into `request.serviceContext`. The org layer ships the Hummingbird middleware by default and the Vapor one when the project uses Vapor.

### Identity and access

38. One issuer. Across processes, asymmetric keys: the authenticating service alone builds `JWTIssuer<UserIdentity>` from its private key, and every process that receives tokens builds `JWTAuthenticator<UserIdentity>` from the public key, so a verifier cannot mint. A monolith that mints and verifies in one process may use a symmetric key through the same `JWTKeyCollection`; it moves to asymmetric keys the day a second process verifies.
39. The org layer owns one `JWTPayload` type that is the identity, `UserIdentity`: `sub` carries the user id as a `UUID`, expiry is verified in `verify(using:)`, no wire twin, no converting initializer. Default claims: `userId`, `role`, `iss`, `iat`, `exp`, with `UserRole` an open string whose named cases are the project's, `.user` and `.admin` by default. Alternative: any further claim the project's use cases read, a tenant or organization id, a plan, is a stored property on the same type; nothing else changes. A process is `ServiceIdentity`, named by the `spiffe://<project>/<process>` URI SAN of the certificate it already presents, read by `ServiceAuthenticator`.
40. Identify a caller and require one as separate steps. The interceptors and the bearer middleware pass an absent credential through anonymously and refuse a present, invalid one; requiring is a private guard in the handler reading `ServiceContext.current?.user` or `.service`, or the requiring tier on HTTP. Absent is `unauthenticated` or 401; a present caller the use case refuses is `permissionDenied` or 403.
41. Apply `BearerAuthenticationInterceptor` to the user service, then `UserSettingsInterceptor` where the module has tenant tables, `CertificateAuthenticationInterceptor(authenticator: ServiceAuthenticator())` to the internal service, nothing to the public one, each with `.apply(_, to: .services([descriptor]))`.
42. Every process verifies a token it receives with the public key; none trusts an identity a caller asserts in metadata, and none mints a credential on a user's behalf. A user crosses a process boundary only as the original token, forwarded by `BearerPropagationInterceptor<UserIdentity>` on the client's user-service descriptors alone; a client that speaks as the process carries no interceptor and is proved by its certificate over mTLS. In a monolith the token is verified once, at the transport.
43. Never declare a `@TaskLocal` for a caller. Pass `.user` and `.service` metadata providers to the logging bootstrap.

### Composition

44. Name the executable after the service or the project and make it the package's one product. `serve` is the default subcommand; a Temporal worker is `worker run` on the same executable. A process never serves an unmigrated schema, and migrations run as the owner over a short-lived client the serving process never keeps. Default: `serve --migrate-database` in the serving container. Alternative: a `migrate` subcommand run as a one-shot job before the rollout, when the platform orders jobs or several replicas start together.
45. Construct every long-lived client, server, application, and worker once in the composition root, under `// MARK:` sections in the order Configuration, Logging, Infrastructure, Composition, then Router and Hummingbird for HTTP, gRPC for gRPC, then Lifecycle, owned by one `ServiceGroup` with graceful shutdown. Both transports in one process share one root, one `ServiceGroup`, and the use cases.
46. In a monolith the root builds one `PostgresClient` per role, one `PostgresDatabase` per module per role over those clients, every module's use cases, and the cross-module injections, then registers every module's services or controllers. Say in a comment which database each use case runs on and why.
47. Read configuration with `ConfigReader` scoped by concern. Require infrastructure values and secrets; default only listen address, port, log level, and the package's own identity. Give each configuration an `init(config:)` extension in the executable's `Configuration` folder, opening key material by path. Read an HTTP listener with `ApplicationConfiguration(reader:)` scoped to `http.server`.
48. Mutually authenticate every internal gRPC connection through two `static func mTLS(config:)` factories on grpc-swift's transport-security types, in the executable's `Configuration` folder. A gateway builds one `GRPCClient` per upstream with a required host and port, the mTLS client factory, `serviceConfig: .defaults`, and the propagating interceptor on user-service descriptors. Bootstrap logging inline with the process name as label and the identity metadata providers, so structured logs reach one aggregator. Default: stdout plus in-process shipping through swift-log-loki. Alternative: any `LogHandler` the deployment prefers, stdout alone for a platform collector or OTLP.

### Tests

49. Give every module a `<Module>CoreTests` target on swift-testing, depending on Core, `swift-log`, `<Project>Authentication`, and `<Project>Testing`. Plain imports; needing `@testable` signals a wrong access level.
50. Test use cases against an actor mock repository and `MockDatabase` through a scoped `withDatabase` helper in `Mocks/`; build subjects with `makeSubject(role:)`. Fixed dates, never `Date()`.
51. Cover the success path of each overload, every guard including the authorization guard asserting the repository was never reached, and every repository-error-to-use-case-error translation. Use-case tests bind no `ServiceContext`; `swift test` needs no infrastructure.
52. Test an HTTP surface by composing the application as `serve` does over mocked use-case protocols (a module) or mocked generated client protocols (a gateway), with a real `JWTIssuer<UserIdentity>` and `JWTAuthenticator<UserIdentity>` over a throwaway key, covering the tier matrix and each error translation.

### Working in an existing package

53. Preserve behavior, naming, shape, and unrelated user changes. Never infer permission to drop tables, discard data, delete a migration, or change the shape; finish the non-destructive work and surface the decision.

## Workflows

Copy the checklist that matches the task and check items off as you go.

```
Build a module or service:
- [ ] 1. Shape: confirm monolith or microservice and HTTP, gRPC, or both; in a monolith, swift package init once and add the module's targets to the existing package, otherwise swift package init --type executable and reshape to <Service>Core, <Service>Postgres, the transport targets, <Service>
- [ ] 2. Core: entities, commands, repositories, scope protocols, use-case contracts with the identity in the signature, typed errors with .forbidden, policies, use cases with their guards, the ports it needs from other modules
- [ ] 3. Tests: <Module>CoreTests with mock repositories and scopes, withDatabase over MockDatabase, makeSubject, the guard/translation/success matrix
- [ ] 4. Postgres: one scope per role, statements, repositories, error translation, tenant policies where rows belong to users, <Module>Migrations in order; in a service CreateServiceRole first and the other roles, in a monolith the roles already exist at the executable
- [ ] 5. Transport: the HTTP surface, the gRPC surface, or both (the checklists below)
- [ ] 6. Root: configuration, logging with the metadata providers, migrations behind --migrate-database (or a migrate one-shot), one client per role and one database per module per role, the cross-module injections, lifecycle
- [ ] 7. swift build, swift test, then exercise the contract, the identity paths, and the roles
```

```
Add the HTTP surface:
- [ ] 1. <Module>HTTP (or <Service>HTTP): openapi.yaml and openapi-generator-config.yaml in the target, types only, package access
- [ ] 2. Contexts and errors in <Project>HTTP for a monolith, in the target itself for a service: IdentityRequestContext, AdminRequestContext, ErrorMiddleware, the Problem types and the use-case error conformances
- [ ] 3. Controllers: one per resource over the module's use-case protocols, registration methods named for their tier, X+Schema.swift conversions that throw
- [ ] 4. Root: the authenticator from the public key, the three tiers with BearerAuthenticationMiddleware, UserSettingsMiddleware where tenant tables exist, IsAuthenticatedMiddleware, every module's controllers mounted, ApplicationConfiguration(reader:), the application in the ServiceGroup
- [ ] 5. Tests over mocked use-case protocols: anonymous → 401, an unverifiable token → 401, the user and admin paths, each error translation
```

```
Add the gRPC surface:
- [ ] 1. Contract: the module's proto files by audience, in <project>-protos tagged and pinned (microservices) or in the package's Protos/ (a gRPC monolith)
- [ ] 2. <Module>GRPC (or <Service>GRPC): one conformance per proto service, feature-local Protobuf/ conversions, each handler insisting on its identity
- [ ] 3. Root: mTLS factories, one GRPCServer with every module's services, the bearer and settings interceptors on the user services, the certificate interceptor on the internal ones, nothing on the public ones
- [ ] 4. Consumers: a gRPC client adapter per port, over one GRPCClient per upstream with the propagating interceptor on user-service descriptors
```

```
Front services with a gateway:
- [ ] 1. Package: swift package init --type executable, reshape to API and <Project>, link only what each target imports
- [ ] 2. Contract: openapi.yaml and openapi-generator-config.yaml in Sources/API/, generating types with package access
- [ ] 3. Contexts and errors: IdentityRequestContext, AdminRequestContext, ErrorMiddleware, the Problem types and their RPCError and HTTPError conformances
- [ ] 4. Controllers: one per resource over generated client protocols, registration methods named for their tier, X+RPC.swift conversions that throw
- [ ] 5. Serve: the authenticator from the public key, one GRPCClient per upstream with mTLS and the propagating interceptor on user-service descriptors, one stub per proto service, the three tiers, the application, one ServiceGroup
- [ ] 6. swift build, then exercise the tiers: a session-issuing route reaches its handler carrying an unverifiable bearer token, and a protected route carrying the same token is refused
```

For a focused change, load only the references the change touches and preserve the established shape.

## Completion gates

Do not call work complete until every applicable gate passes.

- Every package builds in Swift 6 language mode with `swift build` and no concurrency diagnostic silenced rather than resolved, and every `<Module>CoreTests` passes with `swift test` and no infrastructure.
- No module imports another module's Core, Postgres, HTTP, or GRPC target; every cross-module dependency is a protocol in the consumer's Core, satisfied in the composition root.
- Generated protobuf types appear only in GRPC targets and consumer adapters; generated OpenAPI types only in HTTP targets; Postgres types only in Postgres targets and the executable.
- Every use case runs through `withTransaction`; no package declares a `Database`, `PostgresDatabase`, `PostgresScope`, `MockDatabase`, or `PostgresClient.withClient` of its own.
- No Core, Postgres, HTTP, or GRPC target links a driver, grpc-swift, Hummingbird, or Vapor it does not own.
- Every entity identifier is database-generated (`uuidv7()` by default, `gen_random_uuid()` on an older instance) and absent from create inputs; every retryable mutation has owner-enforced idempotency; no table is queried, joined, or referenced by a foreign key from another module.
- The role migrations precede every table; serving connects as the service role, and as the internal role where tenant tables exist, only the migration client as the owner, and no role has `BYPASSRLS`; every module's migrations are registered through its `<Module>Migrations` list in order.
- Where tenant tables exist: every one has a tenant-isolation policy on `app.caller_user_id` with `USING` and `WITH CHECK`; the user services carry `UserSettingsInterceptor` after the bearer interceptor and the identifying tier carries `UserSettingsMiddleware` after the bearer middleware; the policies were exercised as each role with a user, another user, an administrator, and a process. Where none exist, the decision record says so.
- Every gRPC contract is split by audience with the bearer interceptor on the user service, the certificate interceptor on the internal service, and nothing on the public one; every HTTP surface has session-issuing routes outside the authenticating middleware, an identifying tier that admits anonymous requests, a requiring tier that refuses them, and administrative routes reachable only through `AdminRequestContext`.
- Every process that receives a token verifies it with the public key; a token is forwarded only by `BearerPropagationInterceptor<UserIdentity>` on user-service descriptors; no process asserts or mints an identity for another.
- Every use case names its identity in its signature and decides authorization in its body; no handler, controller, interceptor, middleware, or policy decides it.
- The bound user and process appear as `user_id` and `service_name` on every log line of a request.
- Every long-lived client, server, application, and worker is in one `ServiceGroup` with graceful shutdown; no host port is published by a gateway.

If a gate requires an unresolved product, consistency, security, or data-migration decision, stop at the safe boundary and request that decision rather than inventing behavior.
