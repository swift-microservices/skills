---
name: building-swift-services
description: Builds or changes a Swift server application package the swift-microservices way, as a modular monolith or a microservice serving HTTP, gRPC, or both. Modules with Core, Postgres, and transport targets, use cases with the caller in their signature, repositories and prepared statements, database roles and tenant-isolation policies, migrations at boot, versioned proto contracts and gRPC adapters, bearer interceptors, ports between modules, configuration, a composition root with mTLS, and use-case and transport tests. Use when creating a monolith, a module, or a service, adding a feature, use case, repository, migration, RPC, or test to one, wiring one module to another, or editing Package.swift, Sources, or Tests of a Swift server application.
paths: "Package.swift,Sources/**/*.swift,Sources/**/openapi.yaml,Sources/**/*.proto,Tests/**/*.swift"
---

# Building Swift services

One way to build a server application package: the module grammar, target boundaries, folder layout, where each decision lives, and what a test covers. Read applicable `AGENTS.md` files first: their project profile, styles, and recorded exceptions override these conventions. Preserve unrelated established code.

Two choices are made once, before the first file: the **deployment shape** (a monolith: one package, one executable, every module inside; or microservices: one package per module, each with its own executable and database) and the **transport** (HTTP, gRPC, or both). Every combination is valid, and a module is built the same way in each.

Neighbouring skills own the rest, and a task often needs two loaded together: the Swift in every file is **writing-swift-server-code**'s; an HTTP surface or a gateway is **building-swift-http-surfaces**'; a reusable library or `<project>-core` is **building-swift-server-libraries**'; choosing the shape is **designing-swift-systems**'; durable workflows and the worker are **orchestrating-temporal-workflows**'; CI, images, and deployment are **delivering-swift-services**'.

Where a rule says *default* and names an alternative, that is a project choice: take the default unless the project's decision record says otherwise, and never switch it per file.

## Load the references

Read the reference that owns a topic before touching it. Each topic has one home.

| Task | Read |
| --- | --- |
| Every task | [architecture.md](references/architecture.md) — the two shapes, the module grammar, target graphs, the cross-module rule, naming, boundaries, ownership |
| Creating or editing Swift | the writing-swift-server-code skill ([swift-settings.md](../writing-swift-server-code/references/swift-settings.md), [foundation.md](../writing-swift-server-code/references/foundation.md)), and the `swift-concurrency` skill ([AvdLee/Swift-Concurrency-Agent-Skill](https://github.com/AvdLee/Swift-Concurrency-Agent-Skill)) for tasks, actors, `Sendable`, or a data-race diagnostic |
| A package, manifest, source tree, or dependency floor | [service-package.md](references/service-package.md), and [monolith-package.md](references/monolith-package.md) for a monolith's tree and manifest |
| Entities, commands, repositories, scopes, use cases, policies, logging, ports to other modules | [core.md](references/core.md) |
| Scopes, statements, repositories, identifiers, idempotency, state transitions, transactions | [persistence.md](references/persistence.md) |
| Where data lives, migrations and the migration list, roles, row-level security, one database for many modules | [migrations-and-rls.md](references/migrations-and-rls.md) |
| Proto contracts, producer and consumer adapters, status mapping | [grpc-and-protos.md](references/grpc-and-protos.md) |
| The HTTP surface, or a gateway | the building-swift-http-surfaces skill, loaded beside this one |
| Identities, tokens, certificates, interceptors, validation at every process, where authorization lives | [identity-and-access.md](references/identity-and-access.md) |
| Providers, scoping, defaults, native readers, configuration adapters | [configuration.md](references/configuration.md) |
| The executable: logging, clients, servers, the complete service root, two listeners, the gateway root, migrations at boot | [composition.md](references/composition.md) |
| The complete monolith root serving HTTP and gRPC | [monolith-composition.md](references/monolith-composition.md) |
| The server and client transport security factories | [transport-security.md](references/transport-security.md) |
| The Temporal worker's root, role, and configuration | the orchestrating-temporal-workflows skill's [worker.md](../orchestrating-temporal-workflows/references/worker.md) |
| Test targets, mocks, use-case tests, transport tests | [testing.md](references/testing.md) |
| A binding's isolation tests, or Workflow tests | the libraries skill's [testing.md](../building-swift-server-libraries/references/testing.md), or the workflows skill's [testing.md](../orchestrating-temporal-workflows/references/testing.md) |
| The organization's shared core package, or a library adopting `ConfigReader` | the building-swift-server-libraries skill's [organization-layer.md](../building-swift-server-libraries/references/organization-layer.md) and [api.md](../building-swift-server-libraries/references/api.md) |
| Environment values: secrets, JWT keys, credential paths, where Postgres runs | the delivering skill's [environment.md](../delivering-swift-services/references/environment.md) |

## Principles

The rules follow from these. When a situation is not covered, decide from the principle.

1. **A module owns a capability and everything about its data**: tables, identifiers, timestamps, constraints, migrations, contract, and use cases. Nothing else reads its tables or generates its identifiers; in a monolith the rule is kept by review rather than by a network.
2. **The shape and the transport are wiring, not architecture.** A module has the same Core and Postgres targets and the same use cases however it ships and however it is reached. Only the composition root knows which.
3. **A module is movable.** It imports no other module; turning it into a service moves its targets into their own package and swaps what the root injects.
4. **Dependencies point inward; infrastructure SDKs earn their own targets.** Core links `Persistence`, `<Project>Authentication`, and the `swift-log` facade, never a driver, a gRPC runtime, or a server framework.
5. **A protocol exists only where substitution is real**: use cases, repositories, per-use-case scopes, the database, workflow clients, Activity services, and ports between modules. Entities, commands, policies, and configuration stay concrete.
6. **The database is the authority on data, not on permission.** It generates identifiers and dates, enforces uniqueness, guards transitions in `WHERE`, and isolates tenants; a policy never restates what a use case decides.
7. **Retry safety lives with the owner of the side effect**, enforced atomically where the write happens.
8. **A credential says who is calling; the use case decides what they may do.** A token proves a user and a certificate a process; roles travel, permissions do not.
9. **Every process verifies what it receives.** A token crosses a process boundary only as the original credential; a monolith verifies once because it crosses none.
10. **Key material is a file; configuration carries a path**, opened in the composition root and failing loudly at startup.
11. **Share the machinery by tag; duplicate the wiring.** The transaction boundary, interceptors, middleware, identities, and test doubles come from packages (or, in a one-package monolith, from in-package org-layer targets); configuration, roots, transport-security factories, scopes, and mocks are a few lines each package owns.
12. **Translate an error only where the translation adds information**; let a cause propagate to where the distinction is actionable.
13. **Fail at startup, not at the first request.**
14. **Concurrency is structured and compiler-checked; Foundation is modern and minimal**, as the writing-swift-server-code skill states.

## Rules

Each rule is the short form; the linked reference holds the detail and the code.

### Shape, package, and targets

1. A monolith is one package `<organization>-<project>` with one executable target `<Project>`; a microservice is one package `<organization>-<service>` with one executable `<Service>`. The monolith is the smallest shape that fits, never a stepping stone. A gateway is the building-swift-http-surfaces skill's ([gateway.md](../building-swift-http-surfaces/references/gateway.md)).
2. Name a module's targets `<Module>Core`, `<Module>Postgres`, `<Module>HTTP`, `<Module>GRPC`, `<Module>Workflows` (only with Temporal), and one `<Module><Technology>` per provider SDK; in a service `<Module>` is the service name. Use collision-safe names (`AuthenticationRPC`, `AuthenticationServer`) when a dependency owns the default, recorded in `AGENTS.md`. Never `Domain`, `Application`, `Infrastructure`, `Mappings`, or `Adapters` ([architecture.md](references/architecture.md#naming-grammar)).
3. Give every module exactly the transport targets the shape serves; one `GRPCServer` registers every module's services and one router mounts every module's controllers.
4. A module never imports another module's targets; only the executable sees more than one. A module that needs another's behavior declares a port in its own Core, in its own types; the monolith root satisfies it with an executable-local adapter in `Sources/<Project>/Ports/` over the producer's use case, and a service root with a gRPC client adapter ([core.md](references/core.md#ports-to-other-modules)).
5. A monolith's shared HTTP plumbing is one `<Project>HTTP` target ([surface.md](../building-swift-http-surfaces/references/surface.md)).
6. In a one-package monolith, `<Project>Authentication`, `<Project>Persistence`, and `<Project>Testing` are in-package targets until a second package needs them; then they move to a tagged `<project>-core`, as in-package protos move to `<project>-protos` ([monolith-package.md](references/monolith-package.md#source-tree-of-a-monolith)).
7. Use `XUseCase`, `XUseCaseProtocol`, `XUseCaseInput`, `XUseCaseError`, `XUseCaseScope`, `XRepository`, `XRepositoryError`, `XCommand`, `XPolicy`, `XStatement`, `PostgresXRepository`, `Postgres<Module>Scope` (plus `…InternalScope`, `…WorkerScope`), `XService`/`XInternalService`, `XController`. Types spell `ID`, values `Id`.
8. Give every target its direct dependencies, as `MemberImportVisibility` requires, and declare a package only when a target links its product or the build uses its plugin. Use `package` access between targets.
9. Depend on organization packages by tagged URL, never `.package(path:)`.
10. Take `Database` from swift-persistence; `PostgresDatabase`, `PostgresScope`, `PostgresSettings`, and `PostgresClient.withClient` from swift-persistence-postgres; the interceptors and bearer middleware from the swift-authentication transport packages; the identities, `UserSettingsInterceptor`, `UserSettingsMiddleware`, and the test doubles from the org layer. Never redeclare them; duplicate configuration, factories, roots, scopes, migration lists, and mocks per package.

### Core

11. Entities and commands are immutable `Sendable` structs, not `Codable` unless something encodes them; convert with an initializer on the destination beside the adapter that needs it.
12. A fixed invariant is a `guard` at the top of the use case, before I/O, throwing its own typed error; a rule with product-set values is a concrete `XPolicy` with a `.standard` default; a duration is `expiration`.
13. Every business decision is in the use case; a `<Module><Technology>` adapter translates one call and decides nothing.
14. Database-backed use cases are generic over `Database` constrained by their scope protocol, and run each unit of work in `withTransaction` ([core.md](references/core.md#database-boundary)). User operations take `subject: UserIdentity` and `input:`, deriving self-only ids from the subject; public and internal operations take `input:`. One `callAsFunction` per protocol: an administrator's and a process's version of an operation are two use cases named by capability. Delete a use case and its RPC when nothing calls it.
15. Never hold a transaction across a remote call or another module's port, except the bounded single-use-secret rotation read ([core.md](references/core.md#database-boundary)).
16. The database stamps persistence dates; a use case that decides on time reads `Date.now` where it decides.
17. Inject a `Logger` as the last initializer parameter and log the domain event: `info` on success, `warning` on a known refusal, `error` on a genuine failure, the catch-all's cause with `String(reflecting:)` ([core.md](references/core.md#logging-in-use-cases)).

### Persistence

18. A service owns its whole database; a monolith's modules own their tables in one database. Unqualified names, no schema per module, one create migration per table, nothing across a module boundary. By default one instance holds a database and owner per service; other placements are recorded alternatives ([migrations-and-rls.md](references/migrations-and-rls.md#where-a-services-data-lives)).
19. The owning database generates service-owned identifiers (`uuidv7()` by default, `gen_random_uuid()` on an older instance); create inputs omit them; external identifiers are validated and preserved.
20. Name stored dates as nouns (`creation_date`, `creationDate`); store only the SHA-256 digest of a secret token; bcrypt only for passwords.
21. Every remotely retryable mutation is idempotent through a namespaced key enforced atomically by its owner; guard transitions in `WHERE`; liveness-scoped uniqueness is a partial unique index.
22. Statements, row decoding, enum codables, and repositories follow the skeletons in [persistence.md](references/persistence.md#repositories-and-statements). Core never matches on `PSQLError`: repositories translate the SQLSTATEs they know into `XRepositoryError` and let an unknown cause propagate to the use case's catch-all.
23. The owner only migrates; serving connects as `<name>_service` and, with tenant tables, `<name>_internal`; the worker as `<name>_worker`; no role has `BYPASSRLS` ([migrations-and-rls.md](references/migrations-and-rls.md#the-roles)).
24. `Database/Migrations.swift` in the executable lists every migration explicitly, in applied order, and only appends ([migrations-and-rls.md](references/migrations-and-rls.md#the-migration-list)).
25. Row-level security is the default for user-owned rows: one tenant predicate on `app.caller_user_id` in `USING` and `WITH CHECK`, plus `TO "<name>_internal" USING (true)`. A module with tenant tables has `Postgres<Module>Scope` and `Postgres<Module>InternalScope`, and each use case's scope protocol is adopted by the one it may run on. No tenant tables is a recorded decision: one role, one scope, no settings interceptor or middleware ([migrations-and-rls.md](references/migrations-and-rls.md#row-level-security)).
26. A cache is a narrow Core port implemented in a `<Module><Technology>` target, never the source of truth, keyed by tenant, added only for a measured need.

### gRPC

27. A contract has `<Entity>Service` (RPCs grouped anyone / the caller's own / administrators; handlers start with nothing / `requireUser()` / `requireAdministrator()`) and, only when another process calls in, `<Entity>InternalService`. Protos live in a tagged `<project>-protos` in microservices and in `Sources/<Module>GRPC/Protos/` in a gRPC monolith; the generator config sets `accessLevelOnImports` ([grpc-and-protos.md](references/grpc-and-protos.md)).
28. Conversions live in the feature's `Protobuf/` directory and validate transport input; generated types never reach Core.
29. Map typed use-case failures to stable status codes in the producer and back to the port's errors in the consumer; UUIDs lowercased on the wire; refuse an unrecognized enum value.

### HTTP

30. Build every HTTP surface with the building-swift-http-surfaces skill, invoked as a skill rather than read file by file.

### Identity and access

31. One issuer: across processes, asymmetric keys, the issuing module alone holding the private key; a monolith may use a symmetric key until a second process verifies ([identity-and-access.md](references/identity-and-access.md#one-issuer-asymmetric-keys)).
32. Identify and require separately: the interceptors and middleware pass an absent credential and refuse an invalid one; a handler requires what its RPC needs. Absent is `unauthenticated`/401; refused is `permissionDenied`/403.
33. Apply `BearerAuthenticationInterceptor` and then `UserSettingsInterceptor` (where tenant tables exist) to every `<Entity>Service` descriptor and nothing to an internal one. Internal listeners (`<Entity>InternalService`, every process-to-process call) require mTLS; a client-facing listener that apps call through the edge is server TLS with no client certificate and carries only `<Entity>Service`, so a process with both kinds of caller runs two listeners ([identity-and-access.md](references/identity-and-access.md#validation-at-every-process-boundary)).
34. Forward a user only as the original token, with `BearerPropagationInterceptor<UserIdentity>` on the client's `<Entity>Service` descriptors; a process calls as itself, proved by its certificate. Never declare a `@TaskLocal` for a caller.

### Composition

35. The executable is the package's one product; `serve` is the default subcommand, `worker run` the Temporal worker. Migrations run as the owner over a short-lived client before serving: `serve --migrate-database` by default, a `migrate` one-shot or an advisory lock as recorded alternatives ([composition.md](references/composition.md#migrations-at-boot)).
36. `Serve.run()` has `// MARK:` sections Configuration, Logging, Infrastructure, Composition, Router and Hummingbird (HTTP), gRPC (gRPC), Lifecycle, with one `ServiceGroup` owning every long-lived client, server, and application; both transports share one root. Start from the complete roots in [composition.md](references/composition.md#a-grpc-service-with-tenant-tables).
37. The root builds one `PostgresClient` per role and one `PostgresDatabase` per module per role, and says in a comment which database each use case runs on and why.
38. One provider hierarchy, environment before application defaults; native readers first, relative-key `init(config:)` adapters otherwise; no validation in commands ([configuration.md](references/configuration.md)).
39. Prime `TimedCertificateReloader` and pass it to the executable-local `mTLS(config:certificateReloader:)` factories, with explicit trust and full client-side hostname verification, and to `serverTLS(certificateReloader:)` for a client-facing listener; no listener is plaintext ([transport-security.md](references/transport-security.md#transport-security-factories)).

### Tests

40. Every module has `<Module>CoreTests` on swift-testing: actor mock repositories with a dictionary and a `calls` counter, `MockDatabase` through `withDatabase<T>`, `makeSubject(id:role:)` over `Date.reference`, fixed values in `Support/Values.swift`. Plain imports, never `@testable` ([testing.md](references/testing.md)).
41. Cover distinct decisions, success contracts, guards before I/O (`calls == 0`), and meaningful error classifications; no quota per case. Use-case tests bind no `OperationContext` and need no infrastructure.
42. Transport tests are handler or router tests over mocked use-case protocols for tiers and error mapping, plus one live loopback suite per gRPC module, `<Module>GRPCTests`, for token verification, propagation, and wiring, dialing each listener as its callers do (server TLS and a bearer, or mTLS) ([testing.md](references/testing.md#transport-tests)).

### Existing packages

43. Preserve behavior, naming, shape, and unrelated changes. Never infer permission to drop tables, discard data, delete a migration, or change the shape; finish the non-destructive work and surface the decision.

## Workflows

Copy the checklist that matches the task and check items off as you go.

```
Build a module or service:
- [ ] 1. Shape: confirm monolith or microservice and HTTP, gRPC, or both; a monolith gains a module by adding its targets, a service is swift package init --type executable reshaped to its targets
- [ ] 2. Core: entities, commands, repositories, scope protocols, use cases with the identity in the signature and their guards, typed errors with .forbidden, policies, ports to other modules
- [ ] 3. Tests: <Module>CoreTests with actor mocks, withDatabase over MockDatabase, makeSubject, Support/Values.swift
- [ ] 4. Postgres: one scope per role, statements, row decoding, repositories with error translation, table and policy migrations; in a service the role migrations too
- [ ] 5. Transport: the gRPC surface (below), the HTTP surface with the building-swift-http-surfaces skill, or both
- [ ] 6. Root: logging, migrations behind --migrate-database, one client per role and one database per module per role, the Ports/ adapters, transports, one ServiceGroup
- [ ] 7. scripts/check-rls.py and the writing skill's check-swift-settings.py; swift build, swift test, then exercise the contract, the identity paths, and the roles
```

```
Add the gRPC surface:
- [ ] 1. Contract: <Entity>Service and, when another process calls in, <Entity>InternalService, in <project>-protos tagged and pinned (microservices) or in the module's Protos/ (a gRPC monolith)
- [ ] 2. <Module>GRPC: one conformance per proto service, feature-local Protobuf/ conversions, each handler requiring its identity
- [ ] 3. Root: transport-security factories, the bearer and settings interceptors on every <Entity>Service and none on internal services; a client-facing listener (server TLS) with only <Entity>Service, internal services on an mTLS listener
- [ ] 4. Consumers: a gRPC client adapter per port, over one GRPCClient per upstream with propagation on <Entity>Service descriptors
- [ ] 5. <Module>GRPCTests: handler tests over mocked use cases and one loopback TLS suite
```

For a focused change, load only the references the change touches and preserve the established shape.

## Completion gates

Do not call work complete until every applicable gate passes.

- `swift build` succeeds and every `<Module>CoreTests` passes with no infrastructure; the writing-swift-server-code skill's gates pass.
- No module imports another module's targets; every cross-module dependency is a port in the consumer's Core, satisfied in the root by an executable-local adapter or a gRPC client adapter.
- Generated protobuf types appear only in GRPC targets and consumer adapters, OpenAPI types only in HTTP targets, Postgres types only in Postgres targets and the executable; no target links a driver or framework it does not own.
- Every SQL unit of work runs through `withTransaction`; the database types come from the packages or the in-package org layer, never redeclared.
- Service-owned identifiers are database-generated and absent from create inputs; retryable mutations have owner-enforced idempotency; no table is reached from another module.
- `Database/Migrations.swift` lists every migration explicitly in applied order, roles first in a new package and appended when added later; serving never connects as the owner; no role has `BYPASSRLS`.
- Where tenant tables exist: every one has a tenant policy with `USING` and `WITH CHECK` and an internal-role policy; every `<Entity>Service` over them carries `UserSettingsInterceptor` after the bearer interceptor, and the identifying HTTP tier `UserSettingsMiddleware` after the bearer middleware; the policies were exercised as each role. Where none exist, the decision record says so.
- [check-rls.py](scripts/check-rls.py) (`python3 scripts/check-rls.py <package-dir>`) prints OK; it reads the SQL and the migration order, and does not replace exercising the policies as each role.
- Every `<Entity>Service` handler starts with what its RPC requires; internal services carry no application interceptor and sit only on an mTLS listener; a client-facing listener requires no client certificate and carries no internal service; every HTTP surface passes the building-swift-http-surfaces skill's gates.
- Every process that receives a token verifies it; a token is forwarded only by the propagation interceptor on `<Entity>Service` descriptors; authorization is decided in the use case.
- Logs identify the local service and carry `user_id` when a user is bound; every long-lived client, server, application, and worker is in one `ServiceGroup` with graceful shutdown.

If a gate requires an unresolved product, consistency, security, or data-migration decision, stop at the safe boundary and request that decision rather than inventing behavior.
