---
name: designing-swift-systems
description: Designs a Swift distributed system or reshapes one the swift-microservices way: capabilities and service boundaries, data ownership, the communication mechanism per interaction (a local call, gRPC, an event, a durable workflow), consistency and failure semantics, security and trust boundaries, observability, and the staged extraction of a bounded context from a modular monolith. Use when starting a new system, deciding whether something is one service or several, choosing between gRPC, events, and workflows, resolving a dependency cycle or shared table, planning consistency across services, or extracting a module from a monolith into a service.
---

# Designing Swift systems

One way to decide what the services are and how they talk, before any of them is built. It encodes boundary, ownership, and consistency rules learned from running such systems on the [swift-microservices](https://github.com/swift-microservices) packages and an organization layer, `<project>-core`. Preserve every convention unless the user explicitly changes it; where the repository already has an established convention that differs, the repository wins for unrelated code.

Building the service a design calls for, fronting the system with an HTTP gateway, orchestrating Temporal workflows, and delivering images are separate skills; this one produces the design and the extraction plan.

## Load the references

Read the reference that owns a topic before touching that topic. Each topic has exactly one home.

| Task | Read |
| --- | --- |
| Boundaries, communication choice, contracts, consistency, resilience, security, observability, the greenfield sequence | [distributed-systems.md](references/distributed-systems.md) |
| Extracting a bounded context from an existing monolith, step by step | [extraction-runbook.md](references/extraction-runbook.md) — read in full before the first step |

## Principles

The rules follow from these. When a situation is not covered, decide from the principle.

1. **A service owns a capability and everything about its data.** Its database, identifiers, timestamps, constraints, migrations, contract, and lifecycle. Nothing else reads its tables; nothing else generates its identifiers.
2. **Choose the smallest architecture that satisfies current requirements.** A modular monolith with the same Core conventions is a valid first deployment. gRPC is the default remote mechanism; messaging, workflow orchestration, outboxes, and projections are added from a stated requirement, never speculatively.
3. **A boundary earns its network hop.** A service exists where independent behavior, persistence, release, and failure semantics have concrete value. One service per entity, table, endpoint, or team name is not a boundary.
4. **Consistency is decided per interaction, in writing.** Every cross-service read or write names its source of truth, staleness, duplicate handling, and failure behavior.
5. **Retry safety lives with the owner of the side effect.** An idempotency key is enforced atomically where the write happens, never in memory, a caller, or workflow history.
6. **A credential says who is calling; the use case decides what they may do.** A user is proved by a token and a process by its certificate; roles travel, permissions do not. Authorization is a guard in the use case, never in a policy, an interceptor, or the design's trust diagram.
7. **Nothing is plaintext and nothing is published.** Every internal connection is mutually authenticated by a CA the stack issues itself; no internal port reaches a host interface.
8. **Preserve behavior when moving it.** An extraction copies a slice as it is and changes only what the boundary requires; every destructive step is the user's decision.

## Rules

### Boundaries and ownership

1. Capture capabilities, actors, volume, latency, availability, consistency, compliance, integrations, and team maturity before drawing a service.
2. Define a service around one cohesive capability and the data it owns; produce a service map with owned data, inbound contracts, outbound dependencies, and an availability target before implementation.
3. Draw dependency direction and reject cycles. Break one by reconsidering ownership, extracting a third capability, or replacing a synchronous edge with an event or projection.
4. Prefer fewer services when boundaries are uncertain; split only when scaling, ownership, security, release cadence, or failure isolation provides concrete value.
5. Generate every entity identifier in the owning database with `UUID DEFAULT uuidv7()`; a create contract omits it, a consumer stores the returned identifier only after success, and a pending process elsewhere uses its own local identifier.
6. Never share a database, query another service's tables, join across service databases, or make a distributed transaction.

### Communication

7. Choose the least complex mechanism per interaction: a direct use-case call inside one service, gRPC for an immediate typed result, an event for a fact many consumers react to, a durable workflow for a multi-step process with retries, timers, or waits, a projection for a read model that spans services.
8. Do not turn a local function graph into a chain of RPCs; expose capability-level operations that return what the caller's step needs.
9. Design contracts before implementations: name RPCs for capabilities, define validation, response meaning, stable status mapping, deadlines, and idempotency, and keep canonical protos only in `<project>-protos`, evolving `v1` additively.
10. Split every contract by audience — `<Entity>PublicService`, `<Entity>Service`, `<Entity>InternalService` — so identification applies per service, never per method.

### Consistency and reliability

11. Keep a strong invariant inside one service and one local transaction. For a cross-service decision, query the owner and define the timeout behavior; for eventual consistency, publish a fact and keep an idempotent local projection; for a multi-step process, persist workflow state with compensation.
12. Never hold a local transaction across a remote call. Never claim exactly-once delivery; design consumers to tolerate duplicates. Use a transactional outbox only when an atomic mutation plus publication is required.
13. Set caller deadlines from the latency budget; retry only transient failures on idempotent operations, with bounded attempts, backoff, and jitter, and one owner of retries per call chain.
14. Add circuit breaking, load shedding, bulkheads, caching, or hedging only when measured failure or latency patterns justify them, at the caller or transport boundary.

### Security and observability

15. Terminate public TLS at the ingress or gateway; keep every internal gRPC connection mutually authenticated with the stack's CA; keep internal ports off the public ingress.
16. Model process identity as a certificate (`ServiceIdentity`) and user identity as a token (`UserIdentity`); authenticate at the edge, propagate only identity claims, authorize inside the owning use case.
17. Keep secrets as mounted files configured by path; connect as least-privilege database roles; confine user-owned rows with tenant-isolation policies and nothing else in a policy.
18. Establish structured logs with a service label and correlation id shipped in-process to one aggregator, request and error rates and latency per RPC, pool and migration health, and graceful shutdown in every process.

### Extraction

19. Work one bounded context at a time in vertical slices, leaf capabilities first; never a mechanical target-per-layer rewrite of the whole monolith.
20. Release the contract first, build the producer standalone, then keep the consumer's use-case protocol and replace only its implementation with a gRPC client.
21. Move data as an explicit plan with measurement, backup, reconciliation, and rollback criteria; remove old persistence only after cutover passes.
22. Never infer permission to drop tables, discard data, or delete a migration; finish the non-destructive work and surface the decision.

## Workflows

Copy the checklist that matches the task and check items off as you go.

```
Design a system:
- [ ] 1. Capture capabilities, actors, scale, latency, availability, security, compliance, and consistency requirements
- [ ] 2. Define bounded contexts and data ownership; produce the service map; reject cycles
- [ ] 3. Choose the mechanism per interaction and document why each remote boundary exists
- [ ] 4. Define versioned contracts by audience, with failure semantics and idempotency, before producers or consumers
- [ ] 5. Write the consistency record for every cross-service read or write
- [ ] 6. Create and tag <project>-protos and <project>-core; then build each service vertically with the building-swift-services skill
- [ ] 7. Add deadlines, retries, observability, health, and security in proportion to the requirements
```

```
Extract a bounded context:
- [ ] 1. Baseline: repository instructions, dirty state, package graph, callers, persistence, migrations, jobs, configuration, deployment
- [ ] 2. Trace the context end to end; classify every dependency; choose the extraction order
- [ ] 3. Define and release the contract in <project>-protos
- [ ] 4. Build the producer as a standalone service, preserving behavior
- [ ] 5. Adapt the consumer: keep its use-case protocol, replace the implementation with a long-lived gRPC client in ServiceGroup
- [ ] 6. Wire deployment in dependency order: database, migrations, producer, consumer
- [ ] 7. Move and reconcile data explicitly; cut over with rollback viable
- [ ] 8. Retire the old slice only after cutover and rollback criteria pass
```

## Completion gates

Do not call a design or an extraction complete until every applicable gate passes.

- Every service in the map owns one capability and its data; no table is read by two services; no identifier is generated outside its owner; the dependency graph has no cycle.
- Every remote boundary has a stated reason, a chosen mechanism, a versioned contract split by audience, and a consistency record naming source of truth, staleness, duplicates, and failure behavior.
- No local transaction spans a remote call; every retry is bounded and limited to idempotent operations; every mutation that may be retried has an owner-enforced key.
- Every internal connection is mTLS from the stack's CA; users are tokens, processes are certificates, and authorization is placed in use cases only.
- An extraction leaves the consumer's use-case protocol intact, the contract released and tagged, data moved and reconciled, and no direct database access to the extracted context after cutover.
- Every destructive step — dropping tables, deleting migrations, discarding data — was decided by the user, not inferred.

If a gate requires an unresolved product, consistency, security, or data-migration decision, stop at the safe boundary and request that decision rather than inventing behavior.
