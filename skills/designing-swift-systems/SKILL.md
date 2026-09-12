---
name: designing-swift-systems
description: Designs a Swift server system the swift-microservices way, or reshapes one: the deployment shape (a modular monolith or microservices) and the transport (HTTP, gRPC, or both), the modules and the data each owns, the communication mechanism per interaction (a local use-case call, gRPC, an event, a durable workflow), consistency and failure semantics, security with token validation at every process, observability, and whether a module has earned its own service. Use when starting a new system, choosing between a monolith and microservices or between HTTP and gRPC, deciding whether something is one module or several, resolving a dependency cycle or shared table, planning consistency across services, or turning a module into a service.
---

# Designing Swift systems

One way to decide what a system is, how its modules are cut, and how they talk, before any of it is built. It encodes shape, boundary, ownership, and consistency rules learned from running such systems on the [swift-microservices](https://github.com/swift-microservices) packages and an organization layer, `<project>-core`. Preserve every convention unless the user explicitly changes it; where the repository already has an established convention that differs, the repository wins for unrelated code.

Building a module or service, the HTTP surface, and the gateway a design calls for, orchestrating Temporal workflows, and delivering images are separate skills; this one produces the design.

Rules in this skill are conventions the packages and the shared code shape depend on; keep them unless the user changes the vocabulary. Where a rule says *default* and names an alternative, that is a project choice: take the default unless the project's decision record says otherwise, and never switch it per file.

## Load the references

Read the reference that owns a topic before touching that topic. Each topic has exactly one home.

| Task | Read |
| --- | --- |
| Every design: the shape and transport axes, the module, the monolith's rules, where identity is verified, when a module becomes a service | [shapes.md](references/shapes.md) — read in full first |
| Once the shape is microservices: boundaries, communication, contracts, consistency, resilience, security, identity across processes, observability, the greenfield sequence | [distributed-systems.md](references/distributed-systems.md) |
| An interaction that is a fact rather than a request, in either shape: events, the transactional outbox, consumer idempotency, projections | [events-and-projections.md](references/events-and-projections.md) |

## Principles

The rules follow from these. When a situation is not covered, decide from the principle.

1. **Every system is modular; the shape is how many processes it runs in.** A module owns one capability and everything about its data, in one process or in its own. The rules inside a module and between modules do not change with the shape.
2. **Choose the smallest shape that satisfies current requirements.** The monolith is the default and often the final architecture; a service exists where a module has a concrete, measured, or mandated reason to run alone. A monolith is never a compromise.
3. **The transport is who calls, not what the system is.** HTTP for browsers and REST clients, gRPC for apps, partners, and every internal call; both when both call. No business decision lives in a transport.
4. **A boundary earns its network hop.** A module boundary already separates concepts; a process boundary is paid for with a database, a contract, a certificate, and a data migration, so it must buy independent scaling, release, failure, placement, or compliance.
5. **Consistency is decided per interaction, in writing.** Every cross-module or cross-service read or write names its source of truth, staleness, duplicate handling, and failure behavior.
6. **Retry safety lives with the owner of the side effect.** An idempotency key is enforced atomically where the write happens, never in memory, a caller, or workflow history.
7. **A credential says who is calling; the use case decides what they may do.** A user is proved by a token and a process by its certificate; roles travel, permissions do not. Authorization is a guard in the use case, never in a policy, a middleware, an interceptor, or a gateway.
8. **Trust nothing you did not verify yourself.** Every process that receives a token verifies it with the issuer's public key; a token crosses a process boundary only as the original credential; a process is its certificate. In a monolith that is one verification at the transport, because there is no boundary to cross.
9. **Nothing is plaintext and nothing is published.** Every internal connection is mutually authenticated by a CA the stack issues itself; no internal port reaches a host interface.
10. **Moving a module is a wiring change.** A consumer depends on a use-case protocol; what implements it is the composition root's business. Turning a module into a service swaps that implementation and nothing the consumer calls.

## Rules

### Shape and transport

1. Decide the shape and the transport first and write both in the decision record: `monolith` or `microservices`, and `HTTP`, `gRPC`, or `both`. Any combination is valid: an HTTP-only monolith, a gRPC-only monolith, a monolith with both, gRPC services behind an HTTP gateway.
2. Default to the monolith. Recommend microservices only when at least one module has a concrete reason from the list in shapes.md, and name that module and that reason.
3. Choose the transport from the callers. Browsers, REST clients, and OpenAPI consumers get HTTP; apps that speak gRPC, partners, and every internal call get gRPC; both when both exist. In a monolith the HTTP surface is the modules' `<Module>HTTP` targets on one router; in microservices it is the gateway package, `<organization>-api`.
4. Capture capabilities, actors, volume, latency, availability, consistency, compliance, integrations, and team maturity before drawing a module.

### Modules and ownership

5. Define a module around one cohesive capability and the data it owns: its tables, identifiers, timestamps, constraints, migrations, contract, and lifecycle. Nothing else reads its tables; nothing else generates its identifiers. In a monolith the same rules hold inside one database, enforced by review.
6. Name modules and their targets by the grammar in shapes.md: `<Module>Core`, `<Module>Postgres`, `<Module>HTTP`, `<Module>GRPC`, one `<Project>` executable in a monolith; `<Service>` in place of `<Module>` and one executable per service in microservices. Transport targets are per module in both shapes.
7. A module never imports another module's Core, Postgres, or transport target; only the composition root sees more than one module. A consumer module declares the use-case protocol it needs in its own Core, and the root injects the producer's use case (monolith) or a gRPC client adapter conforming to the same protocol (microservices).
8. Draw dependency direction between modules and reject cycles. Break one by reconsidering ownership, extracting a third module, or replacing a synchronous edge with a fact the other side reacts to.
9. Prefer fewer modules when boundaries are uncertain and fewer services always; two modules merge for free, two services cost a data migration.
10. The owning database generates every entity identifier; default `UUID DEFAULT uuidv7()` (Postgres 18), alternative `gen_random_uuid()` on an older instance at the cost of index locality. A create contract omits it, a consumer stores the returned identifier only after success, and a pending process elsewhere uses its own local identifier.
11. Never share tables between modules or services, query another module's tables, join across modules or databases, or make a distributed transaction. Where each service's database lives is a deployment choice recorded once: an instance per service, a database on a shared instance (default), or a schema per service, in that order of isolation. Postgres is the default store; another store is a per-module choice from a measured access pattern, with one store as the truth for each entity.

### Communication

12. Choose the least complex mechanism per interaction: a direct use-case call inside one module, a use-case protocol across modules in a monolith, gRPC for an immediate typed result across processes, an event for a fact many consumers react to, a durable workflow for a multi-step process with retries, timers, or waits, a projection for a read model that spans services.
13. Do not turn a local function graph into a chain of RPCs; expose capability-level operations that return what the caller's step needs.
14. Design contracts before implementations: name RPCs for capabilities, define validation, response meaning, stable status mapping, deadlines, and idempotency, and give canonical protos one home, evolving `v1` additively. Default in microservices: the tagged `<project>-protos` package, because two or more packages consume them. Alternative in a gRPC monolith: in the package itself, until a second package consumes them.
15. Split every contract by audience — `<Entity>PublicService`, `<Entity>Service`, `<Entity>InternalService` — so identification applies per service, never per method. A monolith rarely has an internal audience; a microservice that another process calls always does.
16. An event is the mechanism for a fact that more than one consumer reacts to and that the producer needs no answer to. The owner publishes it through a transactional outbox written in the same transaction as the mutation; a consumer is idempotent by event id; no broker exists before a second consumer does. In a monolith the default publisher is in-process, still through the outbox when the consumer's effect must survive a crash (events-and-projections.md).
17. A projection is a consumer-owned read model kept by idempotent upsert and rebuildable from the owner. It never becomes a source of truth, never replaces a synchronous ask when the answer must be current, and is added from a measured read the owner cannot serve at the needed latency.

### Consistency and reliability

18. Keep a strong invariant inside one module and one local transaction. For a cross-module or cross-service decision, ask the owner and define the timeout behavior; for eventual consistency, publish a fact and keep an idempotent local projection; for a multi-step process, persist workflow state with compensation.
19. Never hold a local transaction across a call to another module or service. Never claim exactly-once delivery; design consumers to tolerate duplicates. Use a transactional outbox only when an atomic mutation plus publication is required.
20. Set caller deadlines from the latency budget; retry only transient failures on idempotent operations, with bounded attempts, backoff, and jitter, and one owner of retries per call chain.
21. Add circuit breaking, load shedding, bulkheads, caching, or hedging only when measured failure or latency patterns justify them, at the caller or transport boundary.
22. A cache is a read optimization decided from a measured read the database cannot serve, never a consistency mechanism: it holds no decision, has a TTL from the interaction's staleness budget, and is reached through a port and adapter the building-swift-services skill describes in its persistence reference.

### Security and observability

23. Terminate public TLS at the ingress or gateway; keep every internal gRPC connection mutually authenticated with the stack's CA; keep internal ports off the public ingress.
24. Model process identity as a certificate (`ServiceIdentity`) and user identity as a token (`UserIdentity`). In a monolith, verify the token once at the transport. In microservices, verify it at the gateway and again at every service that receives it, with the issuer's public key; forward it unchanged with `BearerPropagationInterceptor<UserIdentity>` on user-service descriptors alone; reach internal services by certificate; never trust an identity a caller asserts in metadata, and never mint a credential on a user's behalf.
25. Authorize inside the owning use case. Keep secrets as mounted files configured by path; connect as least-privilege database roles, one set per process; confine user-owned rows with tenant-isolation policies on `app.caller_user_id`, in both shapes, and keep what a caller may do in the use case.
26. Establish structured logs with a service label and correlation id shipped in-process to one aggregator, request and error rates and latency per operation, pool and migration health, and graceful shutdown in every process.

### Turning a module into a service

27. Do it only for a reason from shapes.md that has become concrete, and say which. A separate concept is not a reason; the module boundary already gives that.
28. Release the contract in `<project>-protos` first, split by audience; give the module its own package, database, executable, and role migrations, keeping its Core and Postgres targets as they are; in each consumer keep the use-case protocol and swap the injected implementation for a gRPC client adapter built in the consumer's composition root over mTLS with the propagating interceptor.
29. Never infer permission to move or drop rows, discard data, or delete a migration; finish the non-destructive work and surface the decision.

## Workflow

Copy this checklist and check items off as you go.

```
Design a system:
- [ ] 1. Capture capabilities, actors, callers, scale, latency, availability, security, compliance, and consistency requirements
- [ ] 2. Decide the shape and the transport; write the decision record from shapes.md, naming any split candidate and its concrete reason
- [ ] 3. Define the modules and data ownership; produce the module (or service) map; reject cycles
- [ ] 4. Choose the mechanism per interaction; in microservices, document why each remote boundary exists
- [ ] 5. Define versioned contracts by audience, with failure semantics and idempotency, before producers or consumers (protos only where a process boundary exists)
- [ ] 6. Write the consistency record for every cross-module or cross-service read or write
- [ ] 7. State where identity is verified: once at the transport, or at the gateway and every service
- [ ] 8. Create and tag <project>-core (and <project>-protos in microservices); then build each module or service vertically with the building-swift-services skill
- [ ] 9. Add deadlines, retries, observability, health, and security in proportion to the requirements
```

## Completion gates

Do not call a design complete until every applicable gate passes.

- The decision record states the shape and the transport, and a microservices shape names at least one module with a concrete reason to run alone.
- Every module or service in the map owns one capability and its data; no table is read by two modules; no identifier is generated outside its owner; the dependency graph has no cycle; no module imports another module's targets.
- Every cross-module interaction has a chosen mechanism and a consistency record naming source of truth, staleness, duplicates, and failure behavior; every remote boundary also has a stated reason and a versioned contract split by audience.
- No local transaction spans a call to another module or service; every retry is bounded and limited to idempotent operations; every mutation that may be retried has an owner-enforced key.
- Every event has an owner-side outbox written in the mutation's transaction, a consumer that tolerates duplicates by event id, and, where a projection exists, one that is rebuildable from the owner; no broker exists with fewer than two consumers.
- Every internal connection is mTLS from the stack's CA; users are tokens, processes are certificates; the token is verified once at the transport in a monolith and at every receiving process in microservices; authorization is placed in use cases only; every policy is tenant isolation and nothing else.
- Turning a module into a service leaves the consumer's use-case protocol intact, the contract released and tagged, and every destructive data step decided by the user, not inferred.

If a gate requires an unresolved product, consistency, security, or data-migration decision, stop at the safe boundary and request that decision rather than inventing behavior.
