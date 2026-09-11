# Distributed-system design

Use this reference when designing more than one service, introducing a remote dependency, or creating a system from scratch.

## Contents

- Design inputs and service boundaries
- Communication selection
- Contracts and compatibility
- Data ownership and consistency
- Reliability and failure semantics
- Security and trust boundaries
- Observability and operations
- Greenfield delivery sequence

## Design inputs and service boundaries

Capture requirements before drawing services:

- business capabilities, actors, and ownership;
- expected request volume, payload size, and growth;
- latency and availability objectives;
- correctness and consistency requirements;
- geographic, privacy, compliance, and retention constraints;
- operational team size and deployment maturity;
- external integrations and their failure behavior.

Define a service around a cohesive business capability and the data it owns. A boundary should give the service independent behavior, persistence, release, and failure semantics. Do not create one service per entity, table, endpoint, or team name.

Prefer fewer services when boundaries are uncertain. A modular monolith with the same Core conventions is a valid starting deployment; split only when independent scaling, ownership, security, release cadence, or failure isolation provides concrete value.

Produce a service map before implementation:

| Service | Capability | Owned data | Inbound contracts | Outbound dependencies | Availability target |
| --- | --- | --- | --- | --- | --- |
| `<Service>` | Business responsibility | Tables/records | RPCs/events | Services/providers | Explicit target |

Draw dependency direction and reject cycles unless a real bidirectional business relationship exists. When cycles appear, reconsider ownership, extract a third capability, or use an event/projection to remove synchronous coupling.

## Communication selection

Choose the least complex mechanism that satisfies the interaction:

| Need | Mechanism | Use when |
| --- | --- | --- |
| Behavior inside one service | Direct use-case call | Same ownership and transaction boundary |
| Immediate remote result | gRPC | Caller needs a typed response before continuing |
| Business fact broadcast | Event | Multiple consumers react independently and eventual consistency is acceptable |
| Long-running multi-service process | Durable workflow/orchestration | Steps require retries, compensation, timers, or human/external waits |
| Read model spanning services | Projection/materialized view | Local low-latency reads justify replicated data |

Do not turn a local function graph into a chain of RPCs without revisiting the boundary. Avoid chatty protocols; expose capability-level operations and return the data needed to complete the caller's step.

gRPC is the default synchronous internal transport. Introduce a broker or workflow engine only from explicit delivery/durability requirements, not because the system has multiple services.

## Contracts and compatibility

Design contracts before implementations:

1. Name RPCs for business capabilities rather than CRUD tables.
2. Define request validation, response meaning, and stable error/status mapping.
3. Include stable identifiers and timestamps only when consumers need them.
4. Establish deadlines and maximum payload expectations.
5. Decide idempotency for mutations before permitting retries.
6. Keep canonical contracts in the shared versioned proto package.

Evolve `v1` additively. Add fields using new numbers, preserve existing semantics, reserve removed numbers/names, and create `v2` for breaking behavior. Deploy compatible producers before consumers that require new fields or methods.

Generated protobuf values are transport DTOs. Map them at service/client boundaries and keep each service's Core model independent.

## Data ownership and consistency

Give every service an exclusive database and migration history. Other services use contracts, never SQL access, shared tables, or foreign keys across service databases.

Identifier ownership follows data ownership. The database that owns the canonical entity generates its UUIDv7 identifier. Create contracts omit that identifier, and consumers store the returned foreign identifier only after successful creation. A pending process in another service uses its own locally generated record identifier; it must not reserve the future canonical identifier.

Classify each invariant:

- Keep a strong invariant inside one service and one local transaction.
- For a synchronous cross-service decision, query the owning service and define unavailable/timeout behavior.
- For eventual consistency, publish a fact and maintain an idempotent local projection.
- For a multi-step business process, persist workflow state and define compensation rather than holding locks across services.

Never open a local transaction and make a remote call before committing it. Never claim exactly-once delivery. Design event consumers and imports to tolerate duplicates. If atomic database mutation plus event publication is required, use a transactional outbox and an independently retryable publisher.

Document consistency explicitly for every cross-service read or write:

```text
source of truth: <service>
consumer behavior: synchronous RPC | local projection | workflow
acceptable staleness: <duration or none>
duplicate handling: <idempotency key/rule>
failure behavior: <retry, reject, compensate, defer>
```

## Reliability and failure semantics

Treat every network call as fallible:

- Set caller deadlines from the user-facing latency budget; do not allow unbounded calls.
- Propagate cancellation where useful.
- Retry only transient failures and only when the operation is idempotent or carries an idempotency key.
- Use bounded attempts, exponential backoff, and jitter when retrying.
- Avoid retry amplification across multiple layers; assign retry ownership.
- Bound concurrency and queues to protect dependencies.
- Define behavior for unavailable, deadline exceeded, resource exhausted, and partial response cases.
- Use health/readiness signals for traffic decisions, not as substitutes for runtime recovery.

Add circuit breaking, load shedding, bulkheads, caching, or hedging only when measured failure/latency patterns justify them. Keep resilience policy at the caller or transport boundary, not in Core business entities.

For mutations, define a request identity when clients may retry after an ambiguous timeout. Namespace the key by caller and operation, keep it stable across attempts, and store enough state in the owning service to return the prior outcome safely. The same key with the same canonical input repeats the original effect; the same key with different input is a permanent conflict; a different key still obeys ordinary business uniqueness. Never treat possession of the key as caller authorization.

## Security and trust boundaries

Identify public, private, administrative, and data-sensitive boundaries. Keep internal service ports off the public ingress by default.

- Terminate public TLS at the platform ingress or the gateway's sidecar.
- Mutually authenticate every internal gRPC connection with the stack's own CA; a process is its certificate, and there is no plaintext mode. The certificate names the process (`ServiceIdentity`, from its SPIFFE URI) and the token names the user (`UserIdentity`); authorization is decided in the use case against whichever it was handed, never in a policy or an interceptor.
- Authenticate callers at the edge and propagate only required identity claims.
- Authorize inside the service that owns the protected capability.
- Model process identity separately from end-user identity — a certificate, not a token — and do not trust a caller merely because it is on an internal network.
- Keep secrets as mounted files configured by path, never in source control or environment variables.
- Mark secret configuration values with `isSecret: true`.
- Avoid logging tokens, credentials, sensitive payloads, or raw database errors.
- Connect as a least-privilege database role; confine user-owned rows with tenant-isolation policies on `app.caller_user_id`, and nothing else in a policy.

How a caller is signed, verified, identified per transport, and forwarded between services, and how the roles and row-level security work, is the building-swift-services skill's subject (its identity-and-access and persistence references).

## Observability and operations

Establish consistent signals across services:

- structured logs with a service label, operation/RPC, outcome, and correlation or trace identifiers;
- request rate, error rate, and latency for inbound and outbound RPCs;
- Postgres pool/query health and migration status;
- saturation indicators such as concurrency, queue depth, and resource exhaustion;
- distributed traces across remote boundaries when the operating stack supports them;
- deployment version and contract version visibility.

Log domain events in use cases through the `swift-log` facade, and request, transport, and infrastructure events at the executable and transport boundaries. Keep error messages safe for clients while retaining diagnostic context in internal logs. Ship logs to one aggregator so a single query spans services: each process pushes in-process (no scraping agent), each line carries a `service` label and its logger label, with a request or correlation id as metadata, and the bound `user_id` or `service_name` from the metadata providers. The building-swift-services skill has the bootstrap; the delivering-swift-services skill has the aggregator.

Use graceful shutdown signals and lifecycle management. Stop accepting work, allow bounded in-flight completion, close clients/servers, and make restart behavior safe. Migrations run in the serving container at boot, behind `serve --migrate-database`, before the server binds.

Define alerts from user-impacting symptoms and service objectives, not every logged error.

## Greenfield delivery sequence

1. Write the capability map, service ownership table, interaction map, and non-functional requirements.
2. Challenge every proposed remote boundary; merge services that lack independent ownership or operating value.
3. Define the first vertical user journey and the contracts it needs.
4. Create and release the shared proto package and the organization's core package, `<project>-core`, over the swift-microservices packages.
5. Initialize each required SwiftPM service package with `swift package init --type executable`.
6. Build the owning service from Core outward through Postgres, gRPC, composition, and environment.
7. Build consumers against their local use-case protocols and generated clients.
8. Add dedicated databases, migration jobs, private networking, certificates, secrets, lifecycle, and observability.
9. Verify the first journey end to end, including dependency failure and retry/idempotency behavior.
10. Add the next vertical capability; do not scaffold unused services or infrastructure in advance.

At each step, record decisions that affect contracts, ownership, consistency, security, or operations. Keep implementation details in code and avoid ceremonial architecture documents that duplicate the repository.
