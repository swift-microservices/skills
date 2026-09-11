---
name: orchestrating-temporal-workflows
description: Adds durable orchestration to a Swift service with the Swift Temporal SDK the swift-microservices way: deterministic Workflows in a <Service>Workflows target, one retry-safe Activity per side effect with idempotency derived from immutable input, Core-owned workflow-client and Activity-service ports, signals as commands and queries for observation, timers for expiring conditions, and a worker that is `worker run` on the service executable with its own composition root, its own database role, and no token. Use when a capability needs durable waiting, timers, retries, a saga or multi-step process across services, a long-running background job, a Temporal worker, or when editing Workflows, Activities, signals, queries, or workflow clients.
paths: "Sources/*Workflows/**/*.swift,Sources/*/Worker/**/*.swift"
---

# Orchestrating Temporal workflows

One way to add durable orchestration to a service built with the building-swift-services skill: where Temporal code lives, what a Workflow may and may not do, how an Activity stays retry-safe, and how the worker is composed, identified, and connected. Preserve every convention unless the user explicitly changes it; where the repository already has an established convention that differs, the repository wins for unrelated code.

Temporal is added from a stated requirement — durable waiting, timers, retries across an outage, a multi-step process that must finish — never speculatively. A synchronous capability call stays a gRPC call.

## Load the references

| Task | Read |
| --- | --- |
| Every task | [temporal-workflows.md](references/temporal-workflows.md) — read in full: module boundaries, Workflow and Activity design, clients, transactions, signals and queries, timers, worker composition, naming |

The service package, its roles, and its composition root are the building-swift-services skill's; identity and the certificate a worker presents are described there too. Load that skill beside this one when the change touches Core, Postgres, or `serve`.

## Principles

1. **A Workflow is a durable, deterministic program; everything else is an Activity.** Temporal replays Workflow code from history, so it may compute, wait, and decide, and may not touch a database, a network, a clock, or a random source except through the Workflow context.
2. **Retry safety lives with the owner of the side effect.** An Activity can run again after its effect succeeded, so every write is idempotent where it is owned: a unique constraint, a compare-and-swap, a provider's idempotency key. Workflow history is never the deduplication mechanism.
3. **Temporal history is the workflow state.** There is no second workflow-state store, no scanner that resumes Workflows from business rows, and no reconciliation loop unless the user accepts that consistency model.
4. **A worker is a process, not a user.** It is proved by its certificate, connects to its own database as its own role, and carries the user it acts for as data. It holds no token and forwards none.
5. **One executable, one image.** The worker is a subcommand of the service, deployed from the same image at the same tag, with a composition root of its own.

## Rules

### Module boundaries

1. Keep Temporal SDK code in `<Service>Workflows`: `@Workflow` definitions, `@ActivityContainer` definitions, `TemporalXWorkflowClient` adapters, Temporal options and error translation. Its dependencies are `<Service>Core` and `Temporal`, nothing else.
2. Keep in Core, without importing Temporal: the `XWorkflowClient` protocol use cases call, `XWorkflowState` and `XWorkflowResult`, the `XActivityServiceProtocol` port and its typed errors, and `XActivityService`, a plain struct over the use cases the worker runs.
3. The Workflows target implements no SQL, constructs no client, reads no configuration, and owns no lifecycle.

### Workflow design

4. Use Workflow code only for deterministic orchestration. Reach time, timers, conditions, Activities, signals, and queries through `WorkflowContext`. No database, gRPC, HTTP, email, filesystem, environment, `UUID()`, or `Date()` in a Workflow.
5. Nest `Input` under the Workflow; make every value crossing Temporal `Codable` and `Sendable`; return an `XWorkflowResult`, never a bare scalar.
6. Keep workflow state `.inProgress` until the Activity that establishes a terminal outcome succeeds. Let cancellation and Activity failures propagate; never report a terminal state early.

### Activities

7. Put every external side effect in an Activity, one side effect each. Minting a secret and delivering it are two Activities; deleting it is a third.
8. Derive a stable, namespaced idempotency key from immutable Workflow input or a caller-owned pending-record id, such as `<service>-<process>-<recordId>`, and reuse it on every attempt. Never mint a UUID in Workflow code or per retry, and never preallocate another service's entity identifier: pass the caller-owned id, receive the owner's generated id from the Activity, persist it retry-safely.
9. Configure explicit timeouts and retries. Leave dependency outages retryable; translate invalid state, conflicting canonical input, and permanent consistency failures to non-retryable `ApplicationError` at the Activity boundary. Do not inspect `ApplicationError.type` strings in Workflow code.
10. Give an Activity a distinct registration name with `@Activity(name:)` whenever two containers on one worker would otherwise share a method name; watch the worker log for `Duplicate activity registration`.
11. Group a feature's Activities in one `@ActivityContainer` that takes one narrow Core service protocol; nest Activity input values under the container.

### Clients, transactions, signals, queries, timers

12. Define the client protocol in Core and implement it as `TemporalXWorkflowClient` in Workflows, holding only the long-lived `TemporalClient` and the task queue.
13. Derive the workflow ID from the immutable domain identifier, `<service>-<feature>-<id>`, and start with `idReusePolicy: .rejectDuplicate` and `idConflictPolicy: .useExisting`. Do not catch `WorkflowAlreadyStartedError` on top of them.
14. Commit local database work first, then start or signal. Never call Temporal inside `withTransaction`. Keep start and signal distinct; no signal-with-start, no resume-from-database, no periodic reconciler unless the user explicitly requires it.
15. A signal is a command that returns once Temporal accepted it; it never waits for completion and never returns an identifier a later Activity has not created. A query observes and has no side effect. Keep `XWorkflowState` separate from persisted business state.
16. For an expiring condition, race `context.condition` against `context.timeout` and catch Temporal's `CanceledError`, not Swift's `CancellationError`. On the timed-out branch run the expiration Activity before assigning `.expired`, so a cancelled parent is observed before a terminal state is written.
17. Let SDK errors propagate from the adapter and classify them where the distinction is actionable; never funnel every Temporal failure into one `.unavailable` case.

### The worker

18. The worker is `worker run` on the service executable: `Worker` a command group in `<Service>/Worker/`, `Run` its composition root in the same section order as `serve`. It opens no server, reads no verifying key, and is deployed from the service's image with `worker run` as its command, at the same tag.
19. It connects to its own service's database directly, as `<service>_worker` with its own secret and a `USING (true)` policy, over `PostgresDatabase<Postgres<Service>WorkerScope>(client:logger:)` that only its composition root builds. The use cases it runs take `input:` alone, and the worker scope is the only scope conforming to their scope protocols, so `serve` cannot build them.
20. It reaches every other service through that service's `<Entity>InternalService`, as itself, proved by its certificate: no token, no interceptor on its clients. The receiving service binds it with `CertificateAuthenticationInterceptor(authenticator: ServiceAuthenticator())` and hands its use case a `service: ServiceIdentity`.
21. The user a workflow acts for is a `UUID` in the workflow input, passed as data, never a `subject:` and never a token.
22. Configure the client and worker with the SDK's own readers, `TemporalClient.Configuration(configReader:)` and `TemporalWorker.Configuration(configReader:)` over the `temporal` scope, with the namespace named for the environment and `TEMPORAL_WORKER_HEARTBEATINTERVALMS` set. Use the stack's mTLS client factory for an in-stack server; TLS with the system trust roots and the provider's API key for a managed engine.
23. Own the worker, its Postgres client, and every long-lived client its Activities use in one `ServiceGroup` with graceful shutdown.

## Workflow

Copy this checklist and check items off as you go:

```
Add a workflow:
- [ ] 1. Core: XWorkflowClient protocol, XWorkflowState and XWorkflowResult, XActivityServiceProtocol with typed errors, XActivityService over the worker's use cases
- [ ] 2. Workflows target: <Feature>Workflow with nested Input, signals and queries, timers for expiring conditions; <Feature>Activities with one side effect each and idempotency from input; Temporal<Feature>WorkflowClient with deterministic IDs
- [ ] 3. Postgres: CreateWorkerRole migration, Postgres<Service>WorkerScope conforming only to the worker use cases' scopes
- [ ] 4. serve: one long-lived TemporalClient in ServiceGroup, the workflow-client adapter injected into the use cases, every start or signal after the transaction commits
- [ ] 5. worker run: Worker group and Run composition root; worker-role PostgresClient and database; interceptor-free internal-service clients; TemporalWorker with explicit workflows and containers; one ServiceGroup
- [ ] 6. Environment: the SDK's required worker keys, the worker application running the service image with `worker run`
- [ ] 7. swift build, swift test, then run a workflow end to end: start, signal, query, expiry, and an Activity retried after its side effect
```

## Completion gates

Do not call work complete until every applicable gate passes.

- `<Service>Core` imports no Temporal; `<Service>Workflows` imports no Postgres, protobuf, or configuration.
- Every Workflow is free of side effects and nondeterminism; every side effect is one Activity with an idempotency key derived from immutable input, and no Activity name collides on the worker.
- Every start or signal happens after the local transaction committed; no transaction spans a Temporal call.
- Workflow IDs are deterministic with `.rejectDuplicate` and `.useExisting`; signals return without waiting; queries have no side effects.
- The worker is `worker run` with its own composition root, connects as the worker role to its own database and to other services through their internal services as itself, holds no token, and is in a `ServiceGroup` with the Temporal client or worker.
- The worker's environment carries the SDK's required keys and a heartbeat interval; a missing one fails at startup, not on the first task.

If a gate requires an unresolved product, consistency, or data-migration decision, stop at the safe boundary and request that decision rather than inventing behavior.
