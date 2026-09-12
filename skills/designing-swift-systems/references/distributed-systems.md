# Distributed systems: the microservices section

Use this reference once the shape is microservices (shapes.md decides that): more than one process, a remote dependency, a gateway in front. Everything here builds on the modules the shape reference defines; a service is a module with its own process and database.

## Contents

- Design inputs and service boundaries
- Communication selection
- Contracts and compatibility
- Data ownership and consistency
- Reliability and failure semantics
- Security and trust boundaries
- Identity across processes
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

Define a service around a cohesive business capability and the data it owns. A boundary should give the service independent behavior, persistence, release, and failure semantics. Do not create one service per entity, table, endpoint, or team name; the reasons that earn a service are listed in shapes.md, and a module that has none of them stays a module.

Prefer fewer services when boundaries are uncertain. Two modules in one process cost nothing to merge later; two services with two databases cost a data migration.

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

gRPC is the default synchronous internal transport. Introduce a broker or workflow engine only from explicit delivery/durability requirements, not because the system has multiple services. When the interaction is a fact rather than a request, events-and-projections.md owns the outbox, the consumer, and the projection.

## Contracts and compatibility

Design contracts before implementations:

1. Name RPCs for business capabilities rather than CRUD tables.
2. Split every contract by audience: `<Entity>PublicService` for anyone, `<Entity>Service` for a signed-in user, `<Entity>InternalService` for another process. Identification is applied per proto service, never per method.
3. Define request validation, response meaning, and stable error/status mapping.
4. Include stable identifiers and timestamps only when consumers need them.
5. Establish deadlines and maximum payload expectations.
6. Decide idempotency for mutations before permitting retries.
7. Keep canonical contracts in one home, nested by organization, service, and version: the shared versioned proto package `<project>-protos` by default, because more than one package consumes them (a gRPC monolith may keep them in its own package until that is true).

Evolve `v1` additively. Add fields using new numbers, preserve existing semantics, reserve removed numbers/names, and create `v2` for breaking behavior. Deploy compatible producers before consumers that require new fields or methods.

Generated protobuf values are transport DTOs. Map them at service/client boundaries and keep each service's Core model independent. A consumer keeps its own use-case protocol and entity; the generated client is an implementation behind that protocol, which is why a consumer does not change when a module becomes a service.

## Data ownership and consistency

Give every service an exclusive database and migration history. Other services use contracts, never SQL access, shared tables, or foreign keys across service databases.

Where that database lives is decided per environment, not per service, and recorded once: an instance per service (complete isolation, N clusters to run), one instance with a database and owner per service (the default: logical isolation Postgres enforces itself, one cluster to run, cluster-wide recovery and role names), or a schema per service (cheapest, and held apart only by review). The building skill's persistence reference weighs the three with the recovery, pooling, replica, connection-budget, and placement concerns that usually decide. Postgres is the default store; a module may own a different store when its measured access pattern is a different shape, provided one store stays the truth for each entity and no transaction spans two stores.

Identifier ownership follows data ownership. The database that owns the canonical entity generates its identifier (`uuidv7()` by default, `gen_random_uuid()` on an older instance). Create contracts omit that identifier, and consumers store the returned foreign identifier only after successful creation. A pending process in another service uses its own locally generated record identifier; it must not reserve the future canonical identifier.

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
- Mutually authenticate every internal gRPC connection with the stack's own CA; a process is its certificate, and there is no plaintext mode. The certificate names the process (`ServiceIdentity`, from its `spiffe://<project>/<process>` URI) and the token names the user (`UserIdentity`); authorization is decided in the use case against whichever it was handed, never in a policy or an interceptor.
- Model process identity separately from end-user identity, a certificate rather than a token, and do not trust a caller merely because it is on an internal network.
- Keep secrets as mounted files configured by path, never in source control or environment variables.
- Mark secret configuration values with `isSecret: true`.
- Avoid logging tokens, credentials, sensitive payloads, or raw database errors.
- Connect as a least-privilege database role; confine user-owned rows with tenant-isolation policies on `app.caller_user_id`; what a caller may do is the use case's decision.

## Identity across processes

This is the rule that makes microservices different from a monolith, where the token is verified once at the transport.

**A token is verified by every process that receives it.** The gateway verifies it with the issuer's public key and binds the caller; each service it calls verifies the same token again with the same public key before its own interceptor binds the caller for its own use cases. Verification is a signature check against a public key, cheap enough to repeat, and it is the only thing that makes a service's authorization decision its own rather than an inherited assumption.

**A token crosses a process boundary only as the original bearer credential.** The gateway and any service that calls a user-facing service forward the caller's token unchanged with `BearerPropagationInterceptor<UserIdentity>`, applied to that upstream's user-service descriptors alone, so a public service is dialled with nothing and an internal one is reached by certificate. No process forwards an identity as metadata it asserts, no process trusts a `user_id` header, and no process mints a credential on a user's behalf: there is one issuer, the authenticating service, with the private key, and everyone else holds the public key.

**A process proves itself by certificate.** Worker-to-service and service-to-service calls on internal contracts carry no user token; the caller is its certificate over mTLS, verified by `CertificateAuthenticationInterceptor` against the stack's trust domain, and the internal use case is handed a `ServiceIdentity`. When such a call acts for a named user, the user id is a field of the request, the internal use case checks the process is one it expects, and it reaches every row through the internal role rather than by impersonating the user.

**The tenant reaches the policy in each service on its own.** Each service's `UserSettingsInterceptor` binds `PostgresSettings.user(_:)` from the caller it verified, so the tenant policy in each database sees the user that service verified, not one a caller claimed.

The mechanics of signing, verifying, binding, and forwarding are the building-swift-services skill's (its identity-and-access and http references); this section fixes where they apply.

## Observability and operations

Establish consistent signals across services:

- structured logs with a service label, operation/RPC, outcome, and correlation or trace identifiers;
- request rate, error rate, and latency for inbound and outbound RPCs;
- Postgres pool/query health and migration status;
- saturation indicators such as concurrency, queue depth, and resource exhaustion;
- distributed traces across remote boundaries when the operating stack supports them;
- deployment version and contract version visibility.

Log domain events in use cases through the `swift-log` facade, and request, transport, and infrastructure events at the executable and transport boundaries. Keep error messages safe for clients while retaining diagnostic context in internal logs. Ship logs to one aggregator so a single query spans services: each process pushes in-process (no scraping agent), each line carries a `service` label and its logger label, with a request or correlation id as metadata, and the bound `user_id` or `service_name` from the metadata providers. The building-swift-services skill has the bootstrap; the delivering-swift-services skill has the aggregator.

Use graceful shutdown signals and lifecycle management. Stop accepting work, allow bounded in-flight completion, close clients/servers, and make restart behavior safe. Migrations run before the server binds: in the serving container at boot behind `serve --migrate-database` by default, or as a `migrate` one-shot ahead of the rollout when the platform orders jobs.

Define alerts from user-impacting symptoms and service objectives, not every logged error.

## Greenfield delivery sequence

1. Write the capability map, the shape decision record, the service ownership table, the interaction map, and the non-functional requirements.
2. Challenge every proposed remote boundary against the reasons in shapes.md; merge services that lack one into a module of another, or into a monolith.
3. Define the first vertical user journey and the contracts it needs, split by audience.
4. Create and release the shared proto package, `<project>-protos`, and the organization's core package, `<project>-core`, over the swift-microservices packages.
5. Initialize each service package with `swift package init --type executable`, and the gateway package `<organization>-api` when browsers or REST clients are among the callers.
6. Build the owning service from Core outward through Postgres, gRPC, composition, and environment, with the building-swift-services skill.
7. Build consumers against their local use-case protocols and generated clients, verifying the token at each service and forwarding it on user-facing descriptors alone.
8. Add dedicated databases, migration jobs, private networking, certificates, secrets, lifecycle, and observability.
9. Verify the first journey end to end, including dependency failure and retry/idempotency behavior.
10. Add the next vertical capability; do not scaffold unused services or infrastructure in advance.

At each step, record decisions that affect contracts, ownership, consistency, security, or operations. Keep implementation details in code and avoid ceremonial architecture documents that duplicate the repository.
