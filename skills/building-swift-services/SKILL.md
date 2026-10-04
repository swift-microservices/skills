---
name: building-swift-services
description: Builds or changes a Swift server application package the swift-microservices way, as a modular monolith or as a microservice, over HTTP, gRPC, or both. Modules with Core, Postgres, and transport targets, use cases with the caller in their signature, repositories and prepared statements, database roles and tenant-isolation policies, versioned proto contracts and gRPC adapters, bearer interceptors, configuration, a composition root with mTLS, migrations at boot, and infrastructure-free use-case tests. Use when creating a monolith, a module, or a service, adding a feature, use case, repository, migration, RPC, or test to one, or when editing Package.swift or Sources of a Swift server application.
paths: "Package.swift,Sources/**/*.swift,Sources/**/openapi.yaml,Tests/**/*.swift"
---

# Building Swift services

One way to build a server application package: the module grammar, target boundaries, folder layout, where each decision lives, and what a test covers. It encodes conventions learned from running such systems on the [swift-microservices](https://github.com/swift-microservices) packages and an organization layer, `<project>-core`. Read applicable `AGENTS.md` files first: their project profile, styles, and recorded exceptions override these general conventions. Preserve unrelated established code.

Two choices are made before the first file and never again per file: the **deployment shape** (a monolith: one package, one executable, every module inside; or microservices: one package per module, each with its own executable and database) and the **transport** (HTTP, gRPC, or both). Every combination is valid, and a module is built the same way in every one of them.

Neighbouring skills own the rest, and a task often needs two of them loaded together: the Swift inside every file follows **writing-swift-server-code**; an HTTP surface — a module's `<Module>HTTP` target, the router tiers, the OpenAPI document, or a gateway package in front of services — is **building-swift-http-surfaces**; a reusable library or `<project>-core` is **building-swift-server-libraries**; choosing the shape is **designing-swift-systems**; durable workflows are **orchestrating-temporal-workflows**; CI, images, and deployment are **delivering-swift-services**.

Rules in this skill are conventions the packages and the shared code shape depend on; keep them unless the user changes the vocabulary. Where a rule says *default* and names an alternative, that is a project choice: take the default unless the project's decision record says otherwise, and never switch it per file.

## Load the references

Read the reference that owns a topic before touching that topic. Each topic has exactly one home.

| Task | Read |
| --- | --- |
| Every task | [architecture.md](references/architecture.md) — the two shapes, the module grammar, target graphs, movability, boundary and ownership rules |
| Creating or editing Swift | the writing-swift-server-code skill: [swift-settings.md](../writing-swift-server-code/references/swift-settings.md), [foundation.md](../writing-swift-server-code/references/foundation.md), [style.md](../writing-swift-server-code/references/style.md) |
| Anything touching tasks, actors, `Sendable`, isolation, or a data-race diagnostic | the `swift-concurrency` skill, [AvdLee/Swift-Concurrency-Agent-Skill](https://github.com/AvdLee/Swift-Concurrency-Agent-Skill) — install it; this skill does not restate it |
| Creating or reshaping a package, manifest, or dependency set | [service-package.md](references/service-package.md) — the dependency baseline, source trees, monolith and service manifests |
| Entities, commands, repositories, scopes, use cases, policies, logging, cross-module protocols | [core.md](references/core.md) |
| Scopes, statements, transactions, identifiers, idempotency, migrations, the roles, row-level security, one database for many modules | [persistence.md](references/persistence.md) |
| Proto contracts, producer and consumer adapters, status mapping | [grpc-and-protos.md](references/grpc-and-protos.md) |
| The HTTP surface, or a gateway | the building-swift-http-surfaces skill — load it beside this one |
| The identities, tokens, certificates, interceptors and middleware, validation at every process, where authorization lives | [identity-and-access.md](references/identity-and-access.md) |
| Providers, scoping, defaults, native readers, and configuration adapters | [configuration.md](references/configuration.md) |
| The executable: configuration, logging bootstrap, clients, servers, the monolith, service, worker, and gateway roots | [composition.md](references/composition.md) |
| The test target, mocks, what a use-case test covers, transport tests | [testing.md](references/testing.md) |

## Principles

The rules follow from these. When a situation is not covered, decide from the principle.

1. **A module owns a capability and everything about its data.** Its tables, identifiers, timestamps, constraints, migrations, contract, and use cases. Nothing else reads its tables; nothing else generates its identifiers. In microservices a module is a service; in a monolith it is a set of targets in one package, and the ownership rules are the same, kept by review rather than by a network.
2. **The shape and the transport are wiring, not architecture.** A module has the same Core and Postgres targets whether it ships alone or beside ten others, and the same use cases whether they are reached by a route, an RPC, or both. Only the composition root knows which.
3. **A module is movable.** Its transport targets are its own and it imports no other module. Turning a module into a service moves its targets into their own package and swaps what the composition root injects; nothing inside the module changes.
4. **Dependencies point inward; infrastructure SDKs earn their own targets.** Core links `Persistence`, `<Project>Authentication`, and the `swift-log` facade, never a driver, a gRPC runtime, or a server framework. Focused standards or computation libraries may stay in Core when a wrapper adds no useful seam; the adapter translates infrastructure and the use case decides.
5. **A protocol exists only where substitution is real.** Use cases, repositories, per-use-case scopes, the database, workflow clients, Activity services, and the port one module needs from another. Entities, commands, policies, and configuration stay concrete.
6. **The database is the authority on data, not on permission.** It generates service-owned identifiers and dates, enforces uniqueness, guards state transitions in the `WHERE` clause, and isolates tenants with policies. Application code never re-implements what a constraint states, and a policy never restates what a use case decides.
7. **Retry safety lives with the owner of the side effect.** An idempotency key is enforced atomically where the write happens, never in memory, a caller, or workflow history.
8. **A credential says who is calling; the use case decides what they may do.** A user is proved by a token and a process by its certificate; roles travel, permissions do not. Identification is shared infrastructure applied per RPC service or router tier; the decision is a guard in the use case, against the identity in its signature.
9. **Every process verifies what it receives.** A token is checked with the issuer's public key by each process it reaches and crosses a process boundary only as the original credential. A monolith verifies once because it crosses none.
10. **Key material is a file; configuration carries a path.** Keys and certificates are mounted, opened in the composition root, and fail loudly at startup naming the path.
11. **Share the machinery by tag; duplicate the wiring.** The transaction boundary, the interceptors and middleware, the identities, and the test doubles come from the packages. Configuration, composition roots, transport-security factories, scopes, and mock repositories are eight lines a package owns.
12. **Translate an error only where the translation adds information.** Let a cause propagate and classify it where the distinction is actionable.
13. **Fail at startup, not at the first request.** Required configuration, key files, and certificates are checked before the process serves.
14. **Concurrency is structured and compiler-checked; Foundation is modern and minimal.** Swift 6 language mode with strict concurrency and no silenced diagnostic, one `ServiceGroup` owning every long-lived task, FoundationEssentials and `FormatStyle`, and dependency traits that keep full Foundation out. These are the writing-swift-server-code skill's principles, and every package here follows them.

## Rules

### Shape, package, targets, and naming

1. Choose the shape once: a monolith is one package `<organization>-<project>` with one executable target `<Project>`; a microservice is one package `<organization>-<service>` with one executable target `<Service>`. An HTTP gateway in front of services is a package `<organization>-api` with exactly two targets, `API` and `<Project>`, and no Core or Postgres, built with the building-swift-http-surfaces skill. Never call the monolith a stepping stone; it is the smallest shape that fits.
2. Name a module's targets `<Module>Core`, `<Module>Postgres`, `<Module>HTTP`, and `<Module>GRPC`; add `<Module>Workflows` only with Temporal, and one `<Module><Technology>` leaf per third-party provider SDK. In a service the module name is the service name, so the targets read `<Service>Core`, `<Service>GRPC`, and so on. Use collision-safe names when dependency modules already own the defaults, such as `AuthenticationRPC` and `AuthenticationServer`; record the exception in `AGENTS.md`. Never `Domain`, `Application`, `Infrastructure`, `Mappings`, or `Adapters`.
3. Give every module the transport targets the shape serves and no other: an HTTP-only monolith has `<Module>HTTP` per module and no GRPC target; a gRPC-only one the reverse; a monolith serving both has both. Transport targets are per module in every shape, so a gRPC monolith registers `CatalogGRPC`'s and `UsersGRPC`'s services on one `GRPCServer` and an HTTP monolith mounts `CatalogHTTP`'s and `UsersHTTP`'s controllers on one router.
4. A module never imports another module's Core, Postgres, HTTP, or GRPC target. Only the executable sees more than one module. Where a module needs another's behavior, its Core declares the use-case protocol or narrow client port it needs, and the composition root injects the producer module's use case (a monolith) or a gRPC client adapter conforming to the same protocol (microservices).
5. In a monolith, put the request contexts, the error middleware, and the problem types that every `<Module>HTTP` shares in one `<Project>HTTP` target that each of them links; a service's single `<Service>HTTP` holds them itself, and a gateway's `API` does.
6. Use `XUseCase`, `XUseCaseProtocol`, `XUseCaseInput`, `XUseCaseError`, `XUseCaseScope`, `XRepository`, `XRepositoryError`, `XCommand`, `XPolicy`, `XStatement`, `PostgresXRepository`, `Postgres<Module>Scope` (plus `…InternalScope`, `…WorkerScope`), `XPublicService`/`XService`/`XInternalService`, `XController`.
7. Keep Core independently buildable and free of anything that talks to a network. It links `Persistence`, `<Project>Authentication`, the `swift-log` facade, and focused libraries such as `swift-crypto` or WebAuthn, including their standard types; never Postgres, gRPC, protobuf, Hummingbird, Vapor, a logging backend, configuration, or a provider SDK.
8. Give every target its direct dependencies in `Package.swift`, and declare a package only when a target links one of its products. Use `package` access between targets; `public` only from separately consumed packages.
9. Depend on organization packages by tagged URL, never `.package(path:)`. Publish and tag the shared package before a package pins it.
10. Take `Database` from swift-persistence, `PostgresDatabase`, `PostgresScope`, `PostgresSettings`, and `PostgresClient.withClient` from swift-persistence-postgres, the interceptors from swift-authentication-grpc, the bearer middleware from swift-authentication-hummingbird or swift-authentication-vapor, and the identities, `UserSettingsInterceptor`, `UserSettingsMiddleware`, and the test doubles from `<project>-core`; never redeclare them. Duplicate configuration, transport-security factories, composition roots, scopes, migrations lists, and mock repositories per package.

### Core

11. Model entities and commands as immutable `Sendable` structs. Start with primitive values; introduce a value object only for an established invariant or behavior.
12. Entities, commands, values, and enums in Core are not `Codable`: protobuf conversions and Postgres's encoding protocols never need it. The usual `Codable` types in Core are the workflow state and result a workflow-client port returns; elsewhere a type earns the conformance only where something encodes it.
13. Convert with an initializer on the destination, in an extension beside the adapter that needs it: `init(item: Item)` on a protobuf message, `init(request:) throws` on a use-case input, `init(_ status:)` on a mirrored enum.
14. Follow the writing-swift-server-code skill for the Swift itself — Swift 6 language mode, the four shared upcoming features on every library, executable, and test target, the settled concurrency rules, FoundationEssentials, and dependency traits — and the `swift-concurrency` skill ([AvdLee/Swift-Concurrency-Agent-Skill](https://github.com/AvdLee/Swift-Concurrency-Agent-Skill)) for any task that touches tasks, actors, isolation, `Sendable`, or a data-race diagnostic. Neither is optional and this skill does not repeat them.
15. Apply a fixed invariant as a `guard` at the top of the use case, before any I/O, throwing the use case's own typed error. Keep a rule that carries product-set values as a plain `XPolicy` struct, passed by value with a `.standard` default, never a protocol. Name a duration `expiration`.
16. Keep every business decision in the use case. A `<Module><Technology>` adapter translates one Core call into one SDK call and back; it never decides whether something applies.
17. Use a protocol for a substitutable collaborator; a focused standards library may be passed concretely when abstraction adds no value. A policy is not a collaborator: it is a value the composition root builds from configuration, with a `.standard` default for tests.
18. Declare database-backed use cases against `Database<Scope>`, constrained by their scope protocol, and run each SQL unit of work with `withTransaction`; no-database operations need neither. User operations take `subject: UserIdentity` and business `input:` when needed, deriving self-only resource IDs from the subject, so a self-only operation takes no id: a person's own record is `GetProfile`, not `GetUserByID` with their own id; omit empty input carriers. Authorize before I/O. Public and internal operations take `input:`; internal peers are admitted by mTLS and use cases enforce business invariants.
19. Never hold a transaction across a remote call, and in a monolith never across a call into another module's use case. The sole exception is one fast read during single-use-secret rotation, with an explicit deadline well under the pool's wait time and rollback on dependency failure; never remote writes or workflow calls.
20. Persistence-owned dates are stamped by the database with `DEFAULT NOW()`, so a use case never carries "now" for a creation or update date. Default: no clock in a use case. Alternative: inject a `Clock` only where a use case decides on time, an expiry check or a grace period, so a test can fix it; never to stamp a stored date.
21. Inject a `Logger` into every use case and log the domain event there: `info` on success, `warning` on a known refusal, `error` on a genuine failure, with searchable identifiers and never a secret. The catch-all that maps to `.unknown` logs the cause with `String(reflecting:)`. The `Logger` is the last initializer parameter.

### Persistence

22. A service owns its whole database; a monolith owns one database in which each module owns its tables. In both, unqualified table names, no module- or service-named schema, one create migration per table, and no query, join, or foreign key across a module boundary. Where that database lives is the deployment's choice, recorded once: an instance per service, one instance with a database and owner per service (default), or a schema per service; the ownership rule holds in all three, and shared tables are never one of them. Postgres is the default store; a module whose measured access pattern needs another store owns it the same way, through a Core port and a driver or adapter target, keeps one store as the truth for each entity, and never spans two stores with one transaction.
23. The owning database generates service-owned entity identifiers; omit those from create commands and requests and return them after insertion. Externally assigned standard/provider identifiers, such as WebAuthn credential IDs, are validated and preserved. Never generate another module's identifier. Default: `UUID DEFAULT uuidv7()` on Postgres 18. Alternative: `gen_random_uuid()` on an older instance, at the cost of index locality.
24. Name stored dates as nouns: `creation_date`, `update_date`, `expiration_date`, and `creationDate` in Swift. Spell identifiers `ID` in type names, as Apple's APIs do (`GetUserByIDUseCase`, `GetUserByIDStatement`), and `Id` in variables, parameters, properties, and cases (`userId`, `invalidId`).
25. Model a non-identifier secret as one Core value type that mints and digests; persist only the SHA-256 digest; reserve bcrypt for passwords.
26. Make every remotely retryable mutation idempotent where the side effect is owned: a stable namespaced key enforced atomically, returning the prior outcome for the same input and rejecting reuse with different input.
27. Guard every state transition in the `WHERE` clause and treat the absent row as the lost race. Enforce liveness-scoped uniqueness with a partial unique index over the active states.
28. Migrations run as the instance's owner; nothing that serves data connects as the owner; no role has `BYPASSRLS`; and a tenant-scoped role and an unscoped internal role are distinct roles with their own secrets, so which client a use case is built over decides what it can see. Roles belong to the process, so a package has one set. Default naming: `<name>_service` from `CreateServiceRole`, the first migration; `<name>_internal` from `CreateInternalRole` when any module has tenant tables; `<name>_worker` from `CreateWorkerRole` with Temporal, where `<name>` is the service or the project. Alternative: any naming, provided the role migrations precede the tables and the migration client is the only owner connection.
29. The executable's `Database/Migrations.swift` is the one migration list. It adds every migration by hand, role and table alike, in the order databases apply them — the role migrations before any table, then each module's tables and policies in module dependency order — and only appends. A `<Module>Postgres` declares its migration types and no list of its own.
30. Row-level security is the default for tables whose rows belong to end users in a multi-user application, and its main concern is tenant isolation: a policy confines a request to the caller's rows, `user_id = NULLIF(current_setting('app.caller_user_id', true), '')::uuid`, while what the caller may do stays in the use case. The tenant reaches the policy as `PostgresSettings.user(_:)`, bound by `UserSettingsInterceptor` after the bearer interceptor on gRPC and by `UserSettingsMiddleware` after the bearer middleware on HTTP, applied per transaction by the database. The internal and worker roles see every row through `TO "<role>" USING (true)`. A module with tenant tables has two scope types, `Postgres<Module>Scope` and `Postgres<Module>InternalScope`, and a use case declares which it runs on so the compiler refuses the other. Alternative: a single-tenant application, an internal tool, a deployment per customer, or a module whose tables are not user-owned has no policies, one service role, one scope, and no settings interceptor or middleware; that is a decision recorded once, not an omission. Where the tenant is an organization rather than a user, the setting and the predicate name that id instead, and the org layer's settings helper carries it.
31. A cache is infrastructure the composition root owns, reached from Core through a narrow `<Entity>Cache` port in the consumer's `Ports/` and implemented in a `<Module><Technology>` target such as `<Module>Valkey`. It never holds a decision, never replaces the database as the source of truth, carries a TTL chosen from the use case's staleness budget, and stores nothing tenant-scoped under a key that omits the tenant. Add one only for a measured read the database cannot serve.

### gRPC contracts and transport

32. Canonical `.proto` files have one home, nested by organization, module, and version, starting at `v1` and evolving it additively. Split every contract by audience: `<Entity>PublicService`, `<Entity>Service`, `<Entity>InternalService`. Default in microservices: the tagged `<project>-protos` package, because two or more packages consume them. Alternative in a gRPC monolith: `Sources/<Module>GRPC/Protos/` with the generator plugin in the same package, because one package consumes them; they move to `<project>-protos` the day a second package does. A gRPC monolith keeps the same audience split but rarely has an internal service: its worker reaches its own database directly and no other process calls in; one appears the day another process does.
33. Put protobuf conversions in the feature's `Protobuf/` directory as `X+Protobuf.swift`; perform transport validation in the conversion initializer. Keep generated messages out of Core.
34. Map typed use-case failures to stable status codes in the producer; map them back to local errors in the consumer. Never let `PSQLError`, SQLSTATE, or `RPCError` reach Core. Format UUIDs lowercased on the wire; refuse an unrecognized enum value.

### HTTP transport

35. Build every HTTP surface with the building-swift-http-surfaces skill: one OpenAPI document per `<Module>HTTP` (or `<Service>HTTP`), generating types with `package` access; controllers over the module's use-case protocols; three router tiers (session-issuing and health routes outside any authenticating middleware, an identifying tier with `BearerAuthenticationMiddleware` and then `UserSettingsMiddleware` wherever a module has tenant tables, a requiring tier under `IsAuthenticatedMiddleware`); administrative routes at the resource's path behind `AdminRequestContext`; RFC 9457 problem details. An HTTP gateway in front of services is that skill's too.

### Identity and access

36. One issuer. Across processes, asymmetric keys: the authenticating service alone builds `JWTIssuer<UserIdentity>` from its private key, and every process that receives tokens builds `JWTAuthenticator<UserIdentity>` from the public key, so a verifier cannot mint; both package types take a `JWTKeyCollection`, and `<Project>Authentication` adds the EdDSA `init(privateKey:)` and `init(publicKey:)` conveniences. A monolith that mints and verifies in one process may use a symmetric key through the same `JWTKeyCollection`; it moves to asymmetric keys the day a second process verifies.
37. The org layer owns `UserIdentity` as the user JWT payload, user roles, and user context/logging helpers. Verify required claims in `verify(using:)`. Service peers are admitted by transport mTLS; internal operations do not bind an application principal.
38. Identify a caller and require one as separate steps. The interceptors and the bearer middleware pass an absent credential through anonymously and refuse a present, invalid one; requiring is a private guard in the handler reading `ServiceContext.current?.user`, or the requiring tier on HTTP. Absent is `unauthenticated` or 401; a present caller the use case refuses is `permissionDenied` or 403.
39. Apply `BearerAuthenticationInterceptor` and then tenant `UserSettingsInterceptor` only to user descriptors. Public and internal descriptors carry no application authentication interceptor; all backend descriptors remain behind an mTLS listener.
40. Every process verifies a token it receives with the public key; none trusts an identity a caller asserts in metadata, and none mints a credential on a user's behalf. A user crosses a process boundary only as the original token, forwarded by `BearerPropagationInterceptor<UserIdentity>` on the client's user-service descriptors alone; a client that speaks as the process carries no interceptor and is proved by its certificate over mTLS. In a monolith the token is verified once, at the transport.
41. Never declare a `@TaskLocal` for a caller. Pass the `.user` metadata provider to logging bootstrap and identify the local process with its service label.

### Composition

42. Name the executable after the service or the project and make it the package's one product. `serve` is the default subcommand; a Temporal worker is `worker run` on the same executable. A process never serves an unmigrated schema, and migrations run as the owner over a short-lived client the serving process never keeps. Default: `serve --migrate-database` in the serving container. Alternative: a `migrate` subcommand run as a one-shot job before the rollout, when the platform orders jobs or several replicas start together.
43. Construct owned long-lived runnable clients, servers, applications, and workers once in the composition root, under `// MARK:` sections in the order Configuration, Logging, Infrastructure, Composition, then Router and Hummingbird for HTTP, gRPC for gRPC, then Lifecycle, owned by one `ServiceGroup` with graceful shutdown. A worker substitutes Worker for transport sections. Recorded borrowed SDK HTTP singletons are a lifecycle exception; see [composition.md](references/composition.md). Both transports in one process share one root, one `ServiceGroup`, and the use cases.
44. In a monolith the root builds one `PostgresClient` per role, one `PostgresDatabase` per module per role over those clients, every module's use cases, and the cross-module injections, then registers every module's services or controllers. Say in a comment which database each use case runs on and why.
45. Build one provider hierarchy in the executable: environment overrides before application-specific `InMemoryProvider` defaults, with deployment defaults owned there and policy defaults derived from Core's `.standard`. Prefer native configuration readers; extend missing ones with relative-key `init(config:)` adapters. Reject malformed security overrides, pass no default/path arguments, use unit-suffixed numeric duration keys, and keep validation out of commands. Honor recorded project exceptions; see [configuration.md](references/configuration.md).
46. Prime `TimedCertificateReloader` from `NIOCertificateReloading`, pass it to executable-local `mTLS(config:certificateReloader:)` factories, and own it once in `ServiceGroup`. Use explicit CA trust and full client-side hostname verification. Temporal always has a separate credential scope and reloader. Keep logging/bootstrap and lifecycle in the root; configuration and validation belong in native readers or focused adapters.

### Tests

47. Give every module a `<Module>CoreTests` target on swift-testing, depending on Core, `swift-log`, `<Project>Authentication`, and `<Project>Testing`. Plain imports; needing `@testable` signals a wrong access level.
48. Test use cases against an actor mock repository and `MockDatabase` through a scoped `withDatabase` helper in `Mocks/`; build subjects with `makeSubject(role:)`. Fixed dates, never `Date()`.
49. Cover distinct business decisions, success contracts, authorization before I/O, and meaningful error classifications. Parameterize equivalent cases; a test per error enum case or overload is not a quota. Use-case tests bind no `ServiceContext` and require no infrastructure. See [testing.md](references/testing.md) for test ownership and consolidation.

### Working in an existing package

50. Preserve behavior, naming, shape, and unrelated user changes. Never infer permission to drop tables, discard data, delete a migration, or change the shape; finish the non-destructive work and surface the decision.

## Workflows

Copy the checklist that matches the task and check items off as you go.

```
Build a module or service:
- [ ] 1. Shape: confirm monolith or microservice and HTTP, gRPC, or both; in a monolith, swift package init once and add the module's targets to the existing package, otherwise swift package init --type executable and reshape to <Service>Core, <Service>Postgres, the transport targets, <Service>
- [ ] 2. Core: entities, commands, repositories, scope protocols, use-case contracts with the identity in the signature, typed errors with .forbidden, policies, use cases with their guards, the ports it needs from other modules
- [ ] 3. Tests: <Module>CoreTests with mock repositories and scopes, withDatabase over MockDatabase, makeSubject, focused decision, guard, translation, and success coverage
- [ ] 4. Postgres: one scope per role, statements, repositories, error translation, tenant policies where rows belong to users, the migration types; in a service the role migrations too, in a monolith the roles already exist at the executable
- [ ] 5. Transport: the gRPC surface (the checklist below), the HTTP surface with the building-swift-http-surfaces skill, or both
- [ ] 6. Root: configuration, logging with the metadata providers, migrations behind --migrate-database (or a migrate one-shot), one client per role and one database per module per role, the cross-module injections, lifecycle
- [ ] 7. swift build, swift test, then exercise the contract, the identity paths, and the roles
```

```
Add the gRPC surface:
- [ ] 1. Contract: the module's proto files by audience, in <project>-protos tagged and pinned (microservices) or in the package's Protos/ (a gRPC monolith)
- [ ] 2. <Module>GRPC (or <Service>GRPC): one conformance per proto service, feature-local Protobuf/ conversions, each handler insisting on its identity
- [ ] 3. Root: mTLS factories, one GRPCServer with every module's services, the bearer and settings interceptors on user services, transport mTLS for internal services, no application interceptor on public or internal descriptors
- [ ] 4. Consumers: a gRPC client adapter per port, over one GRPCClient per upstream with the propagating interceptor on user-service descriptors
```

For a focused change, load only the references the change touches and preserve the established shape.

## Completion gates

Do not call work complete until every applicable gate passes.

- The package builds with `swift build` and every `<Module>CoreTests` passes with `swift test` and no infrastructure.
- The writing-swift-server-code skill's gates pass: the shared Swift settings on every owned target, no silenced concurrency diagnostic, conditional Foundation imports and modern format styles only, no `NIOFoundationCompat`, and explicit `traits:` on `swift-configuration`, `hummingbird`, and `swift-openapi-runtime`.
- No module imports another module's Core, Postgres, HTTP, or GRPC target; every cross-module dependency is a protocol in the consumer's Core, satisfied in the composition root.
- Generated protobuf types appear only in GRPC targets and consumer adapters; generated OpenAPI types only in HTTP targets; Postgres types only in Postgres targets and the executable.
- Every SQL unit of work runs through `withTransaction` on swift-persistence's `Database`; nontransactional-store and no-database operations need no artificial database dependency; `PostgresDatabase`, `PostgresScope`, and `PostgresClient.withClient` come from swift-persistence-postgres, and `MockDatabase` from `<Project>Testing`.
- No Core, Postgres, HTTP, or GRPC target links a driver, grpc-swift, Hummingbird, or Vapor it does not own.
- Every service-owned entity identifier is database-generated (`uuidv7()` by default, `gen_random_uuid()` on an older instance) and absent from create inputs; externally assigned identifiers retain their documented authority; every retryable mutation has owner-enforced idempotency; no table is queried, joined, or referenced by a foreign key from another module.
- The role migrations precede every table; serving connects as the service role, and as the internal role where tenant tables exist, only the migration client as the owner, and no role has `BYPASSRLS`; `Database/Migrations.swift` adds every migration explicitly, in applied order.
- Where tenant tables exist: every one has a tenant-isolation policy on `app.caller_user_id` with `USING` and `WITH CHECK`; the user services carry `UserSettingsInterceptor` after the bearer interceptor and the identifying tier carries `UserSettingsMiddleware` after the bearer middleware; the policies were exercised as each role with a user, another user, an administrator, and a process. Where none exist, the decision record says so.
- Every gRPC contract is split by audience with the bearer interceptor on the user service, transport mTLS admission for internal services, and no application interceptor on public or internal descriptors; every HTTP surface passes the building-swift-http-surfaces skill's gates.
- Every process that receives a token verifies it with the public key; a token is forwarded only by `BearerPropagationInterceptor<UserIdentity>` on user-service descriptors; no process asserts or mints an identity for another.
- Every use case names its identity in its signature and decides authorization in its body; a transport may additionally gate a route collection or verb by verified JWT role without database lookups, but resource and business authorization remain in the use case. Database policies isolate tenants.
- Logs identify the local service and include `user_id` when a verified user is bound.
- Every long-lived client, server, application, and worker is in one `ServiceGroup` with graceful shutdown.

If a gate requires an unresolved product, consistency, security, or data-migration decision, stop at the safe boundary and request that decision rather than inventing behavior.
