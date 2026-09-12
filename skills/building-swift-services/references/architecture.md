# Architecture specification

## Contents

- Two shapes, one grammar
- The module
- Target graph of a monolith
- Target graph of a microservice
- Target graph of a gateway
- What each target owns
- Movability and the cross-module rule
- Dependency direction
- Business rules, policies, and adapters
- Share the machinery, duplicate the wiring
- Naming grammar
- Boundary rules
- Ownership rules

Use a module-oriented SwiftPM package, not textbook layer names. The package is the deployment unit; targets are compile-time boundaries inside it.

## Two shapes, one grammar

A system is built from modules, and two decisions are made once for the whole system:

- **Deployment shape.** A *monolith* is one package with one executable and every module inside it. *Microservices* are one package per module, each with its own executable and its own database. The word monolith always means the modular one; it is the smallest shape that fits the requirements and often the final one, never a stepping stone.
- **Transport.** *HTTP*, *gRPC*, or *both*. Every combination with every shape is valid: an HTTP-only monolith, a gRPC-only monolith, a monolith serving both, gRPC microservices behind an HTTP gateway, HTTP microservices.

The module is built the same way in every combination. What changes is the composition root: how many modules it composes, which transport targets it registers, and whether a module's port is satisfied by a neighbor's use case or by a gRPC client.

## The module

A module is one bounded capability with its own Core and Postgres targets, its own use cases, its own tables, and, for each transport the shape serves, its own transport target. In microservices a module is a service; the grammar substitutes `<Service>` for `<Module>` and nothing else changes.

```text
<Module>Core            entities, repositories, use cases, the ports it needs from other modules
<Module>Postgres        scopes, statements, repositories, migrations
<Module>HTTP            controllers over the module's use cases, the module's OpenAPI document   # with HTTP
<Module>GRPC            generated-service conformances over the module's use cases              # with gRPC
<Module>Workflows       Temporal workflows, Activities, workflow clients                         # with Temporal
<Module><Technology>    one provider SDK's adapter                                               # per SDK
```

## Target graph of a monolith

One package `<organization>-<project>`, one executable `<Project>`, every module inside:

```text
<Project>                                  # the composition root: composes every module
├── CatalogCore
├── CatalogPostgres ──────→ CatalogCore
├── CatalogHTTP ──────────→ CatalogCore, <Project>HTTP     # with HTTP
├── CatalogGRPC ──────────→ CatalogCore                    # with gRPC
├── UsersCore
├── UsersPostgres ────────→ UsersCore
├── UsersHTTP ────────────→ UsersCore, <Project>HTTP
├── UsersGRPC ────────────→ UsersCore
├── UsersBcrypt ──────────→ UsersCore                      # one per provider SDK
├── <Project>HTTP                                          # with HTTP: contexts, error middleware, problem types
└── <Project> ────────────→ every module's targets
```

`<Project>HTTP` exists because the request contexts, the error middleware, and the problem types are shared by every `<Module>HTTP` and owned by none of them. It holds transport plumbing only, never a use case or an entity. A gRPC monolith needs no such target: every `<Module>GRPC` is self-contained and the interceptors are applied in the root.

One database, one executable, one `ServiceGroup`. The root builds one `PostgresClient` per role, one `PostgresDatabase` per module per role, every module's use cases, and then one `GRPCServer` registering every `<Module>GRPC`'s services, one Hummingbird application mounting every `<Module>HTTP`'s controllers, or both.

## Target graph of a microservice

One package `<organization>-<service>`, one executable `<Service>`, one module:

```text
<Service>
├── <Service>Core
├── <Service>Postgres ─────→ <Service>Core
├── <Service>GRPC ─────────→ <Service>Core      # with gRPC
├── <Service>HTTP ─────────→ <Service>Core      # with HTTP; holds its own contexts and error middleware
├── <Service>Workflows ────→ <Service>Core      # only with Temporal
├── <Service><Technology> ─→ <Service>Core      # one per third-party provider SDK
└── <Service> ─────────────→ all required targets
```

Each service owns its database. Services reach each other over gRPC, through the consumer adapter in [grpc-and-protos.md](grpc-and-protos.md), and an HTTP gateway fronts them for people.

## Target graph of a gateway

The HTTP transport of a system whose modules are services. One package `<organization>-api`, two targets, no data:

```text
<organization>-api
├── API ────────→ generated OpenAPI types, contexts, middleware, controllers, RPC conversions
└── <Project> ──→ API   # command tree, configuration, clients, lifecycle
```

Two targets, not four. A gateway owns no entities, no repositories, and no database, so `Core` and `Postgres` targets would be empty. Do not add an `APICore` to mirror the module shape: the only candidates for it are the request contexts and the problem types, and both are transport concerns that belong beside the controllers that use them. Name it `-api`, not `-gateway`: the thing that actually gateways, routing, TLS termination, rate limiting, is the ingress in front of this process; what this package holds is hand-written controllers mapping one contract onto another, an edge service. Its rules are in [http.md](http.md); its root in [composition.md](composition.md).

## What each target owns

| Target | Owns | Must not own |
| --- | --- | --- |
| `<Module>Core` | Entities, repository protocols and errors, repository commands, policies and validators, use-case protocols/inputs/errors/scopes/implementations and the authorization inside them, the protocols it needs from other modules, workflow-client and Activity-service ports and the Activity service itself | SQL, generated messages, RPC status, HTTP status, configuration, server startup, a logging backend, a token or certificate library, another module |
| `<Module><Technology>` | One provider SDK's adapter conforming to a Core port, such as `<Module>Bcrypt` or `<Module>Resend` | Business rules, configuration reading, client construction |
| `<Module>Postgres` | Postgres scopes, one per database role, repositories, prepared statements, the module's table and policy migrations as `<Module>Migrations`; in a service, the role migrations too | Business validation, RPC or HTTP mapping, CLI parsing, a `Database` of its own, another module's tables |
| `<Module>GRPC` | Generated-service conformances, one per proto service, request/input mapping, domain/protobuf mapping, RPC error translation, the per-handler guard that a principal is bound | SQL, environment reading, server construction, an authorization decision |
| `<Module>HTTP` | The module's OpenAPI document and generated types, controllers over the module's use-case protocols, schema conversions, use-case error to problem mapping; in a service, the contexts and error middleware too | SQL, environment reading, application construction, an authorization decision |
| `<Project>HTTP` (monolith only) | Request contexts, error middleware, problem types, the `HTTPError` problem conformance | A controller, a use case, an entity, a route |
| `API` (gateway only) | Generated OpenAPI types, request contexts, error middleware and problem types, controllers over generated client protocols, RPC conversions, route registration | Environment reading, client construction, logging setup, `@main`, a database |
| `<Module>Workflows` | Temporal Workflows, Activity containers, workflow-client adapters, signals, queries, Temporal error translation | SQL implementations, generated protobuf, environment reading, dependency construction |
| `<Project>` or `<Service>` | ArgumentParser command tree, environment configuration, logging bootstrap, dependency construction, the cross-module injections, server, application, and client construction, lifecycle; in a monolith, the role migrations and the ordered migration list; with Temporal, the `worker run` command's second composition root | Reusable business rules |

## Movability and the cross-module rule

A module never imports another module's Core, Postgres, HTTP, or GRPC target. Only the composition root sees more than one module. That single rule is what makes the shape a wiring decision:

- When a consumer module needs another module's behavior, its Core declares the protocol it needs: the producer's `XUseCaseProtocol` when the shapes match, or a narrower client port naming only the operation and the values the consumer needs. Generated protobuf types never appear in it.
- In a monolith the composition root injects the producer module's use case directly. The call is local, and a transaction never spans it, exactly as it never spans a remote call.
- In microservices the composition root injects a gRPC client adapter conforming to the same protocol, the consumer adapter of [grpc-and-protos.md](grpc-and-protos.md).

Turning a module into a service is therefore three steps: release its contract in `<project>-protos`, give the module its own package, database, and executable, and swap what the consumer's root injects. Nothing inside the module changes, and the consumer's Core does not know it happened. Going the other way, folding a service into a monolith, is the same three steps reversed. Neither needs a plan of its own.

The rule has a persistence half: a module owns its tables and no other module queries, joins, or references them with a foreign key, in a monolith's single database exactly as across service databases. A module that needs another module's data asks through the port and stores what it is told, under its own identifiers, as *Ownership rules* below describes.

## Dependency direction

Dependencies point inward. Core has no dependency on another module's implementation. Zero dependencies is not the rule, Swift server libraries routinely ship a small-dependency core, and Core may link a focused library such as `swift-crypto`, the `swift-log` facade, `Persistence` from swift-persistence, and the organization's identities from `<project>-core`. What Core must not link is an infrastructure SDK: a database driver, an HTTP client, a mail or payments provider, a server framework, a concrete logging backend, a gRPC or protobuf runtime. The packages are cut by dependency set so that this holds: the product a domain target links carries the identities and the transaction boundary and nothing that talks to a network (see *The packages* in [identity-and-access.md](identity-and-access.md)).

A third-party SDK is what earns a `<Module><Technology>` target; conforming to a Core protocol does not. Keep those targets leaves that only the composition root depends on. Core is the root of the internal graph, so a mail SDK there makes `<Module>Postgres` link an HTTP client to run SQL, and an email-template edit recompiles every target. The one library Core links that looks like infrastructure is jwt-kit, and only because `UserIdentity` is the token's payload itself: a use case that names a user gets the claims type with it, and nothing else about tokens, no key, no signing, no verification, reaches Core.

Transport targets are leaves too. `<Module>HTTP` links Hummingbird and `<Module>GRPC` links grpc-swift, and neither links the other or Postgres; the executable is the only target that links both transports and the driver.

## Business rules, policies, and adapters

A business rule lives in the use case that applies it. A fixed invariant, a title must not be blank, a currency is three letters, a licence names a major version and a subscription does not, is a `guard` at the top of `callAsFunction`, before any I/O, throwing the use case's own typed error. Do not extract those guards into an `XValidator` whose errors then need an initializer on every use-case error to map them back; the mapping is code that says nothing. When the same invariant applies on create and on update, both use cases state it, and a rule that depends on the row's existing state is applied inside the transaction that reads the row.

An adapter carries no rule. A `<Module><Technology>` target translates one Core call into one SDK call and the SDK's result and errors back into Core values; it does not decide whether a trial is offered, whether a message should be sent, or whether a caller qualifies. The use case makes that decision from the entities it already holds and hands the adapter a plain value, a `trialPeriodDays: Int?` that is `nil` when there is no trial, not a `trialEligible` flag and a `requestTrial` flag for the adapter to combine. The same holds for a repository: SQL states constraints and guards transitions in `WHERE`, but a decision that reads as product policy belongs above it. And the same holds for a transport: a controller or a handler converts, insists that a principal is present, and calls the use case; it never decides what the caller may do.

A rule that carries product-set values, a minimum length, a lifetime, is a plain struct in Core, never a protocol, never injected:

```swift
package struct PasswordPolicy: Equatable, Sendable {
    package static let standard = PasswordPolicy()
    package let minimumLength: Int
    package let requiresNumber: Bool
}
```

Name a rule expressed as numbers `XPolicy`, not `XConfiguration`. Configuration is deployment wiring that varies per environment; a policy is a product decision that would be identical in staging and production. The composition root reads configuration and translates it into policy; being loadable from `ConfigReader` does not make a value configuration. Name a duration `expiration`, matching the `expirationDate` it produces.

Do not inject a concrete collaborator that has no protocol: injection buys substitution, and a concrete type cannot be substituted. Either the seam is real and the parameter is a protocol, or the type is constructed where it is used. A policy is the exception because it is data, not a collaborator: the composition root builds it from configuration and passes it by value into the use case's initializer, which defaults the parameter to `.standard` so a test constructs the use case without it. A validator that applies such a policy, `PasswordValidator(policy:)`, travels the same way; a validator with no values to carry is not a type at all but a guard in the use case.

## Share the machinery, duplicate the wiring

Shared packages carry what is genuinely the same in every package, consumed by tag beside the proto contracts. The [swift-microservices](https://github.com/swift-microservices) packages hold the generic machinery, knowing nothing of the organization: swift-persistence and swift-persistence-postgres for the transaction boundary and the Postgres driver, swift-authentication for the shape of a proven caller, swift-authentication-jwt and -x509 for the two proofs, swift-authentication-grpc, -hummingbird, and -vapor for the transports that bind one. `<project>-core` holds what the organization decides once: the user's claims, the roles, the process's name, the setting the policies read, the interceptor and the middleware that bind it, the test doubles. Every package is one dependency set, so a target links exactly the technology it names (see *The packages* in [identity-and-access.md](identity-and-access.md)).

What stays per package is the wiring: configuration readers, transport-security factories, the composition roots, the scopes, the migration lists, the request contexts, the mock repositories. Those start identical and diverge as systems evolve, and duplicating eight lines costs less than a tag and a bump in every consumer for every change to them. The test of where a shape belongs is whether it would ever differ between two packages: a `Database` protocol never does, a `PostgresConfiguration` does the moment one package gains a role. Do not add another shared package, and do not put configuration or composition into `<project>-core`.

## Naming grammar

- Monolith package: `<organization>-<project>`, lowercase; executable product the lowercase project name, such as `backend`; executable target `<Project>`.
- Service package: `<organization>-<service>`, lowercase; executable product the lowercase service name, such as `catalog`; executable target `<Service>`.
- Gateway package: `<organization>-api`; targets `API` and `<Project>`.
- Module targets: `CatalogCore`, `CatalogPostgres`, `CatalogHTTP`, `CatalogGRPC`. Targets do not repeat the organization prefix; the package name carries it. In a service the module name is the service name.
- Monolith HTTP plumbing: `<Project>HTTP`, such as `BackendHTTP`.
- Optional Temporal target: `CatalogWorkflows`; the worker is `<executable> worker run`, a command group in the executable.
- Provider adapter target: `CatalogBcrypt`, `CatalogResend`: the technology, not the port it implements.
- Business rule value: `PasswordPolicy`, `SessionPolicy`, `EmailValidator`.
- Entity: `Item`.
- Use case: `CreateItemUseCase`; port `CreateItemUseCaseProtocol`; input and typed failure `CreateItemUseCaseInput`, `CreateItemUseCaseError`; narrow scope `CreateItemUseCaseScope`.
- Repository: `ItemRepository`, `ItemRepositoryError`; write intent `CreateItemCommand`.
- Postgres implementation: `PostgresItemRepository`; prepared statement `CreateItemStatement`; scopes `PostgresCatalogScope`, `PostgresCatalogInternalScope`, `PostgresCatalogWorkerScope`; the module's migration list `CatalogMigrations`.
- gRPC service implementations, one per proto service: `ItemPublicService`, `ItemService`, `ItemInternalService`.
- HTTP controller, one per resource: `ItemController`; contexts `IdentityRequestContext`, `AdminRequestContext`; conversions `ItemResponse+Schema.swift` in a module, `ItemResponse+RPC.swift` in a gateway.
- Cross-module port in a consumer's Core: the producer's `XUseCaseProtocol`, or a narrow `<Entity>Client` port such as `AccountClient`; its gRPC implementation `GRPCAccountClient` in the consumer's GRPC target.
- Identities: `UserIdentity` as `subject:`, `ServiceIdentity` as `service:`.
- Temporal workflow, Activities, and client adapter: `ReservationWorkflow`, `ReservationActivities`, `TemporalReservationWorkflowClient`.
- Identifier properties: `xId`, never `xID`. Strict camel case keeps `registrationId` aligned with SQL `registration_id` and proto `registration_id` with no acronym special-casing.

Do not replace these with handlers, interactors, gateways, stores, managers, `Domain`, `Application`, `Infrastructure`, generic `Mappings`, or generic `Adapters` unless the user explicitly changes the vocabulary.

## Boundary rules

Use protocols where they enable a real seam:

- Use-case protocols let transports, callers, and other modules depend on behavior.
- Repository protocols let Core depend on persistence capabilities.
- Per-use-case scope protocols expose only the repositories a use case needs, and which concrete scope adopts them decides which database the use case may run on.
- `Database` from swift-persistence is the transaction boundary and keeps Core decoupled from persistence.
- Cross-module ports let one module's Core depend on another's behavior without knowing whether it is a local call or an RPC.
- Workflow-client protocols let Core start, signal, and query durable orchestration without importing Temporal.
- Activity service protocols let the Workflows target invoke Core-owned behavior without importing Postgres, gRPC, or provider SDKs.

Do not add a protocol merely to mirror every concrete type. Keep entities and command values as structs. Keep configuration and composition concrete at the executable root.

Use typed errors in Core. Map persistence failures into repository errors in persistence, repository errors into use-case errors in Core, and use-case errors into RPC status in GRPC or problem details in HTTP. Reverse that translation at the consumer boundary. Never make Core switch on SQLSTATE, `RPCError`, or `HTTPError`.

Translate an error only where the translation carries information. A one-case adapter enum every failure funnels into, `catch { throw XClientError.unavailable }`, destroys the cause without adding a distinction, so a permanent misconfiguration reports as a retryable outage and the caller retries what can never succeed. Let the infrastructure error propagate and classify it where the difference is actionable. Name a repository error for the constraint that exists: a partial unique index over active states means "an active record exists", not "duplicate email".

## Ownership rules

A module owns:

- its business behavior;
- its canonical contract, the proto services and the OpenAPI document;
- its tables and their migrations, and in a service the whole database;
- its persistence timestamps, identifiers, and constraints;
- in a service, its runtime and deployment lifecycle.

The database that owns an entity also owns generation of that entity's identifier. Define UUID primary keys with `DEFAULT uuidv7()`, omit them from create commands and create requests, and return the inserted entity with its generated identifier. A caller may provide a separate idempotency key when required, but it must not masquerade as the owned entity identifier. Treat the key as an opaque request identity, not a secret or authorization credential; the receiving module owns atomic enforcement and payload-conflict detection.

When one module creates an entity through another, keep the caller's pending state under a caller-owned identifier. Store the foreign identifier only after the owning module returns it. Never preallocate an identifier in the caller, pass it into the owner, or create a matching identifier independently in two tables or two databases.

A consumer owns its local caller-facing model and use-case protocol. Generated protobuf messages are integration DTOs, not shared domain entities.

Do not share a database between services, query another module's tables, or make a distributed transaction. In a monolith the tables share one database and the rule holds by review: a module reaches another's data only through the port in its Core. Add an RPC for synchronous coordination between services. Introduce asynchronous events or an outbox only when delivery and consistency requirements justify it; do not add them speculatively.

When Temporal coordinates a capability, keep orchestration mechanics in `<Module>Workflows` and business/persistence state in Core and Postgres. Do not mirror Temporal history in a second workflow-state store or poll Postgres to reconstruct running workflows. See the orchestrating-temporal-workflows skill.
