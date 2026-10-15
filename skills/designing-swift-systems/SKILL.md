---
name: designing-swift-systems
description: Designs a Swift server system the swift-microservices way, or reshapes one, and plans the ordered setup of its complete stack. The deployment shape (a modular monolith or microservices) and the transport (HTTP, gRPC, or both), the modules and the data each owns, the communication mechanism per interaction (a local use-case call, gRPC, an event, a durable workflow), consistency and failure semantics, security with token validation at every process, observability, the bootstrap order from an empty repository to a running stack, and whether a module has earned its own service. Use when starting a new project or a greenfield system, setting up a complete stack end to end, choosing between a monolith and microservices or between HTTP and gRPC, deciding whether something is one module or several, resolving a dependency cycle or shared table, planning consistency across services, or turning a module into a service.
---

# Designing Swift systems

One way to decide what a system is, how its modules are cut, how they talk, and in which order the stack is set up, before any of it is built. Read applicable `AGENTS.md` files first: their project profile, styles, and recorded exceptions override these general conventions. Preserve unrelated established code.

This skill produces the design and the bootstrap plan. Building a module or service is building-swift-services; its HTTP surface, gateway, or client SDK is building-swift-http-surfaces; `<project>-core`, `<project>-protos`, and other libraries are building-swift-server-libraries; durable workflows are orchestrating-temporal-workflows; CI, images, certificates, and the environment are delivering-swift-services. When choosing frameworks, follow the [Foundation dependency guidance](../writing-swift-server-code/references/foundation.md#dependency-traits-that-pull-in-foundation) and never promise an Essentials-only application from a framework's name.

Where a rule says *default* and names an alternative, that is a project choice: take the default unless the decision record says otherwise, and never switch it per file.

## Load the references

Read the reference that owns a topic before touching that topic. Each topic has exactly one home.

| Task | Read |
| --- | --- |
| Every design: the shape and transport axes, the module, the monolith's rules, where identity is verified, when a module becomes a service, the decision record | [shapes.md](references/shapes.md) — read in full first |
| Once the shape is microservices: boundaries, communication, contracts, consistency, resilience, security, identity across processes, observability | [distributed-systems.md](references/distributed-systems.md) |
| An interaction that is a fact rather than a request, in either shape: events, the transactional outbox, consumer idempotency, projections | [events-and-projections.md](references/events-and-projections.md) |
| Setting up a complete stack from nothing, a new project, or a greenfield system: the ordered steps, their owners, and their gates | [bootstrap.md](references/bootstrap.md) |
| Carrying out a bootstrap step | the owning skill's reference, read in full: building-swift-services' [service-package.md](../building-swift-services/references/service-package.md), [grpc-and-protos.md](../building-swift-services/references/grpc-and-protos.md), [configuration.md](../building-swift-services/references/configuration.md), [composition.md](../building-swift-services/references/composition.md), [testing.md](../building-swift-services/references/testing.md); building-swift-http-surfaces' [surface.md](../building-swift-http-surfaces/references/surface.md), [gateway.md](../building-swift-http-surfaces/references/gateway.md), [client-sdk.md](../building-swift-http-surfaces/references/client-sdk.md); writing-swift-server-code's [swift-settings.md](../writing-swift-server-code/references/swift-settings.md); orchestrating-temporal-workflows' [worker.md](../orchestrating-temporal-workflows/references/worker.md); delivering-swift-services' [library-ci.md](../delivering-swift-services/references/library-ci.md), [services-ci.md](../delivering-swift-services/references/services-ci.md), [delivery.md](../delivering-swift-services/references/delivery.md), [environment.md](../delivering-swift-services/references/environment.md), [certificates.md](../delivering-swift-services/references/certificates.md) |

## Principles

The rules follow from these. When a situation is not covered, decide from the principle.

1. **Every system is modular; the shape is how many processes it runs in.** A module owns one capability and everything about its data. The rules inside and between modules do not change with the shape.
2. **Choose the smallest shape that satisfies current requirements.** The monolith is the default and often the final architecture; a service exists where a module has a concrete, measured, or mandated reason to run alone.
3. **The transport is who calls, not what the system is.** HTTP for browsers and REST clients, gRPC for apps, partners, and every internal call; both when both call. No business decision lives in a transport.
4. **A boundary earns its network hop.** A process boundary costs a database, a contract, a certificate, and a data migration, so it must buy independent scaling, release, failure, placement, or compliance.
5. **Consistency is decided per interaction, in writing.** Every cross-module or cross-service read or write names its source of truth, staleness, duplicate handling, and failure behavior.
6. **Retry safety lives with the owner of the side effect.** An idempotency key is enforced atomically where the write happens, never in memory, a caller, or workflow history.
7. **Separate transport admission from user authorization.** mTLS admits internal peers; user JWTs identify users, whose permissions the user use cases check; internal use cases accept business input and enforce invariants; database policies isolate tenants.
8. **Trust nothing you did not verify yourself.** Every process that receives a token verifies it with the issuer's public key; a token crosses a process boundary only as the original credential; a process is its certificate. In a monolith that is one verification at the transport.
9. **Nothing is plaintext and nothing is published.** Every internal connection is mutually authenticated by a CA the stack issues itself; client-facing edges terminate public TLS at the edge and reach the process over TLS; no port reaches a host interface.
10. **Moving a module is a wiring change.** A consumer depends on a port in its own Core; turning the producer into a service swaps the adapter the root injects and nothing the consumer calls.

## Rules

### Shape and transport

1. Decide the shape and the transport first and write both in the [decision record](references/shapes.md#the-decision-record): `monolith` or `microservices`, and `HTTP`, `gRPC`, or `both`. Any combination is valid.
2. Default to the monolith. Recommend microservices only when at least one module has a concrete reason from shapes.md, and name that module and that reason.
3. Choose the transport from the callers. In a monolith the HTTP surface is the modules' `<Module>HTTP` targets on one router; in microservices it is the gateway package, `<organization>-api`, and apps consume its client SDK, `<organization>-sdk`.
4. Capture capabilities, actors, volume, latency, availability, consistency, compliance, integrations, and team maturity before drawing a module.

### Modules and ownership

5. Define a module around one cohesive capability and the data it owns: tables, identifiers, constraints, migrations, contract, and lifecycle. Nothing else reads its tables or generates its identifiers; in a monolith review enforces the same rules inside one database.
6. Name modules and targets by the grammar in shapes.md: `<Module>Core`, `<Module>Postgres`, `<Module>HTTP`, `<Module>GRPC`, one `<Project>` executable in a monolith; `<Service>` in place of `<Module>` and one executable per service in microservices.
7. A module never imports another module's targets; only the composition root sees more than one module. A consumer declares the port it needs in its own Core, in its own types (`<Entity>Client` with only the operations it calls); the root satisfies it with an executable-local adapter in `Sources/<Project>/Ports/` over the producer's use case (monolith) or a gRPC client adapter (microservices). The producer's use case never conforms to the port directly ([core.md](../building-swift-services/references/core.md#ports-to-other-modules)).
8. Draw dependency direction between modules and reject cycles. Break one by reconsidering ownership, extracting a third module, or replacing a synchronous edge with a fact the other side reacts to.
9. Prefer fewer modules when boundaries are uncertain and fewer services always; two modules merge for free, two services cost a data migration.
10. The owning database generates service-owned identifiers; externally assigned identifiers keep their authority. A consumer stores a returned identifier only after success ([persistence.md](../building-swift-services/references/persistence.md#identifiers-dates-and-secrets)).
11. Never share tables, query or join across modules or databases, or make a distributed transaction. Postgres placement (instance, database, or schema per service) is a project choice recorded once with no default; another store is a per-module choice from a measured access pattern ([persistence.md](../building-swift-services/references/persistence.md#database-ownership-and-migrations)).

### Shared code and contracts

12. Shared code has one home, decided by how many packages consume it. Microservices start with a tagged `<project>-core` and `<project>-protos`. A one-package monolith keeps `<Project>Authentication`, `<Project>Persistence`, `<Project>Testing`, and any `.proto` files in its own package until a second package needs them, then moves them to the tagged packages ([organization-layer.md](../building-swift-server-libraries/references/organization-layer.md)).
13. Design contracts before implementations: capability-named RPCs, validation, response meaning, stable status mapping, deadlines, and idempotency, evolving `v1` additively. Every contract has `<Entity>Service` grouped by who may call and, only when another process calls in, `<Entity>InternalService` ([identity-and-access.md](../building-swift-services/references/identity-and-access.md#two-rpc-services)).

### Communication

14. Choose the least complex mechanism per interaction: a direct call inside one module, a port in the consumer's Core across modules in a monolith, gRPC for an immediate typed result across processes, an event for a fact many consumers react to, a durable workflow for a multi-step process with retries, timers, or waits, a projection for a read model that spans services.
15. Do not turn a local function graph into a chain of RPCs; expose capability-level operations that return what the caller's step needs.
16. An event is for a fact more than one consumer reacts to and the producer needs no answer to: published through a transactional outbox in the mutation's transaction, consumed idempotently by event id, with no broker before a second consumer exists ([events-and-projections.md](references/events-and-projections.md)).
17. A projection is a consumer-owned, rebuildable read model kept by idempotent upsert, added from a measured read the owner cannot serve; it never becomes a source of truth or replaces a synchronous ask that must be current.

### Consistency and reliability

18. Keep a strong invariant inside one module and one local transaction. Across modules or services, ask the owner and define the timeout behavior, publish a fact for eventual consistency, or run a durable workflow with compensating Activities for a multi-step process.
19. Hold no local transaction across another module or service call, except the [bounded single-use-secret rotation read](../building-swift-services/references/core.md#database-boundary). Never claim exactly-once delivery; design consumers to tolerate duplicates.
20. Set caller deadlines from the latency budget; retry only transient failures on idempotent operations, bounded, with backoff and jitter, and one owner of retries per call chain.
21. Add circuit breaking, load shedding, bulkheads, caching, or hedging only when measured failure or latency patterns justify them. A cache is a read optimization with a TTL from the staleness budget, never a consistency mechanism ([persistence.md](../building-swift-services/references/persistence.md#caching)).

### Security and observability

22. Terminate public TLS at the edge (the project's reverse proxy, with strict verification of the origin). A client-facing listener — the gateway, or a monolith apps call directly — is server TLS from the proxy with no client certificate, callers identified by bearer JWT; every internal connection stays on mTLS from the stack's CA, and every internal port off the edge.
23. Verify the original user token at every receiving process, forward it only on `<Entity>Service` descriptors, and authorize resource and business access in the owning use case; an optional API gate may additionally check verified JWT roles without database lookups ([identity-and-access.md](../building-swift-services/references/identity-and-access.md)).
24. Decide tenant isolation in the decision record: row-level security on `app.caller_user_id` where more than one end user owns rows in one database, none for a single-tenant application, an internal tool, or a deployment per customer. Each process connects as its own least-privilege roles ([persistence.md](../building-swift-services/references/persistence.md#row-level-security)).
25. Every process has structured logs with a service label and correlation id shipped to one aggregator, request and error rates and latency per operation, pool and migration health, and graceful shutdown.

### Turning a module into a service

26. Do it only for a reason from shapes.md that has become concrete, and say which. A separate concept is not a reason.
27. Release the contract first, give the module its own package, database, executable, and role migrations, and replace each consumer's executable-local adapter with a gRPC client adapter conforming to the same port; the consumer's port and Core do not change ([shapes.md](references/shapes.md#when-a-module-becomes-a-service)).
28. Never infer permission to move or drop rows, discard data, or delete a migration; finish the non-destructive work and surface the decision.

## Workflow

Copy this checklist and check items off as you go.

```
Design a system:
- [ ] 1. Capture capabilities, actors, callers, scale, latency, availability, security, compliance, and consistency requirements
- [ ] 2. Decide the shape and the transport; write the decision record, naming any split candidate and its concrete reason
- [ ] 3. Define the modules and data ownership; produce the module (or service) map; reject cycles
- [ ] 4. Choose the mechanism per interaction; in microservices, document why each remote boundary exists
- [ ] 5. Define versioned contracts, grouped by caller, with failure semantics and idempotency, before producers or consumers
- [ ] 6. Write the consistency record for every cross-module or cross-service read or write
- [ ] 7. State where identity is verified: once at the transport, or at the gateway and every service
- [ ] 8. Plan the setup from bootstrap.md for the chosen shape — shared targets in-package (monolith) or tagged <project>-core and <project>-protos (microservices), then modules or services, the HTTP surface or gateway and SDK, CI, the environment, first start — and hand each step to its owning skill
- [ ] 9. Add deadlines, retries, observability, health, and security in proportion to the requirements
```

## Completion gates

Do not call a design complete until every applicable gate passes.

- The decision record states the shape and the transport, and a microservices shape names at least one module with a concrete reason to run alone.
- Every module or service owns one capability and its data; no table is read by two modules; no service-owned identifier is generated outside its owner; the dependency graph has no cycle.
- Every cross-module interaction has a mechanism and a consistency record naming source of truth, staleness, duplicates, and failure behavior; every remote boundary has a stated reason and a versioned contract.
- No local transaction spans another module's or service's call except the bounded rotation read; every retry is bounded and idempotent; every retried mutation has an owner-enforced key.
- Every event has an outbox write in the mutation's transaction and a consumer tolerant of duplicates; no broker exists with fewer than two consumers.
- Every internal connection is mTLS from the stack's CA; a client-facing listener is server TLS behind the edge, with no client certificate and only `<Entity>Service`; the token is verified once at the transport in a monolith and at every receiving process in microservices; authorization stays in use cases; every policy is tenant isolation and nothing else.
- A new system has a bootstrap plan in [bootstrap.md](references/bootstrap.md)'s order, with shared code placed by the number of packages that consume it.
- Turning a module into a service leaves the consumer's port and Core intact, the contract released and tagged, and every destructive data step decided by the user.

If a gate requires an unresolved product, consistency, security, or data-migration decision, stop at the safe boundary and request that decision rather than inventing behavior.
