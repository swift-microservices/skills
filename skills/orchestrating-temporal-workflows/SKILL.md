---
name: orchestrating-temporal-workflows
description: Adds durable orchestration to a Swift service with the Swift Temporal SDK the swift-microservices way. Deterministic Workflows in the service's Workflows target, one retry-safe Activity per side effect with idempotency derived from immutable input, Core-owned workflow-client and Activity-service ports, signals as commands and queries for observation, timers for expiring conditions, event-keyed workflows for provider webhooks, time-skipping tests with replayed histories, and a worker that is `worker run` on the service executable with its own composition root, database role, and mTLS credentials and no token. Use when a capability needs durable waiting, a timer or expiry, retries across an outage, a saga or multi-step process across services, fulfillment triggered by a payment or provider webhook, a long-running background job, or a Temporal worker, or when editing Workflows, Activities, signals, queries, workflow clients, or their tests.
paths: "Sources/*Workflows/**/*.swift,Sources/*/Worker/**/*.swift,Tests/*WorkflowsTests/**/*.swift"
---

# Orchestrating Temporal workflows

Durable orchestration for a service built with the building-swift-services skill: where Temporal code lives, what a Workflow may do, how an Activity stays retry-safe, and how the worker is composed, identified, and connected.

Add Temporal from a stated requirement (durable waiting, timers, retries across an outage, a multi-step process that must finish), never speculatively. A synchronous capability call stays a gRPC call.

Read applicable `AGENTS.md` files first: their project profile, styles, and recorded exceptions override these conventions. Preserve unrelated established code. Where a rule names a default and an alternative, the alternative is a project choice recorded once, never switched per file.

## Load the references

| Task | Read |
| --- | --- |
| A Workflow, Activity, payload, workflow client, signal, query, timer, child workflow, or webhook-triggered workflow | [workflows.md](references/workflows.md) |
| The worker command, its database role and scope, Temporal configuration and TLS, the `TemporalClient` in `serve`, a monolith's worker, local development | [worker.md](references/worker.md) |
| Workflow tests, the time-skipping server, recorded histories, replay, Activity-name uniqueness | [testing.md](references/testing.md) |
| A new Workflow end to end | all three |

The service package, its roles, and its serve composition root are the building-swift-services skill's; load it beside this one when the change touches Core, Postgres, or `serve`. Every Swift change follows the writing-swift-server-code skill's [Swift settings](../writing-swift-server-code/references/swift-settings.md) and [Foundation policy](../writing-swift-server-code/references/foundation.md); modern Foundation API never relaxes Workflow determinism or payload compatibility.

## Principles

1. **A Workflow is a durable, deterministic program; everything else is an Activity.** Temporal replays Workflow code from history, so it may compute, wait, and decide, and touches no database, network, `Date.now`, or random source except through the Workflow context.
2. **Retry safety lives with the owner of the side effect.** An Activity can run again after its effect succeeded, so every write is idempotent where it is owned. Workflow history is never the deduplication mechanism.
3. **Temporal history is the workflow state.** No second workflow-state store, no scanner that resumes Workflows from business rows, no reconciliation loop unless the user accepts that consistency model.
4. **A worker is a process, not a user.** It is proved by its certificate, connects to its own database as its own role, and carries the user it acts for as data. It holds no token and forwards none.
5. **One executable, one image.** The worker is a subcommand of the service, deployed from the same image at the same tag, with a composition root of its own.
6. **A payload is a stored contract.** Every value Temporal carries is written into history and decoded again on replay, so it is `Codable`, carries only what its reader needs, and changes the way a wire format changes.

## Rules

Each rule is one line; the linked section holds the code and the detail.

### Workflows and payloads ([workflows.md](references/workflows.md))

1. Temporal SDK code lives in `<Service>Workflows`, which depends on Core, `Temporal`, and `Logging` only. Core holds the `XWorkflowClient` port, the state and result payloads, the Activity-service port, and `XActivityService`, without importing Temporal.
2. Each Activity container file declares a `package` helper whose signature names a Temporal type (the `nonRetryable` `ApplicationError` builder), because Swift 6.3 does not count `@ActivityContainer` expansions as uses of `package import Temporal`.
3. Workflow code reads `context.now`, logs through `context.logger`, and reaches Activities, timers, signals, and queries through `WorkflowContext`; no I/O, environment, `UUID()`, `Date()`, or `Date.now`.
4. Workflow state stays `.inProgress` until the Activity establishing a terminal outcome succeeds; a best-effort step runs after it with bounded attempts.
5. Return an `XWorkflowResult` when a caller awaits or queries the outcome, and `Void` from a fire-and-forget Workflow; never a bare scalar.
6. Every payload is `Codable` and `Sendable`, nested under its Workflow or container, never a Core entity, and changed only by adding optionals ([Payloads](references/workflows.md#payloads)).
7. Start a child Workflow only for a step another trigger also starts, with an ID derived from the parent's input and an execution timeout.

### Activities ([workflows.md](references/workflows.md#activities))

8. One side effect per Activity: issuing a secret, delivering it, and deleting it are three.
9. Derive a namespaced idempotency key from immutable input or a caller-owned id, `<service>-<process>-<recordId>`, reuse it on every attempt, and pass it through the port; never mint a UUID per attempt or preallocate another service's id.
10. One container per feature over one Activity-service protocol. Provider adapters and other services' consumer adapters are Core ports named for the capability (`PasswordHasher`, `VerificationEmailSender`), injected into the Activity service, never into the container.
11. Pass explicit `ActivityOptions` on every call: unlimited attempts with a bounded `startToCloseTimeout` when the effect can wait out an outage, bounded attempts with a `scheduleToCloseTimeout` when it cannot ([Timeouts and retries](references/workflows.md#timeouts-and-retries)).
12. Translate invalid state, conflicting input, and permanent provider rejections to non-retryable `ApplicationError` at the Activity boundary; leave outages retryable; never inspect `ApplicationError.type` in a Workflow.
13. Give an Activity a distinct name with `@Activity(name:)` wherever two containers on one worker would share one.

### Clients, signals, queries, timers ([workflows.md](references/workflows.md#workflow-clients))

14. `TemporalXWorkflowClient` holds only the `TemporalClient` and the task queue, and lets SDK errors propagate.
15. An entity-lifetime Workflow's ID is `<service>-<feature>-<id>` with `.rejectDuplicate` and `.useExisting`, and no `WorkflowAlreadyStartedError` catch. A webhook-triggered Workflow's ID is `<service>-<feature>-<entity>-<eventId>` with `.allowDuplicateFailedOnly`, `.useExisting`, and an execution timeout; it treats the payload as a trigger and re-fetches live state in an Activity ([Event-triggered workflows](references/workflows.md#event-triggered-workflows)).
16. Commit local work, then start or signal; never call Temporal inside `withTransaction`. No signal-with-start, resume-from-database, or reconciler unless the user requires it.
17. A signal returns once Temporal accepted it; a query has no side effect; `XWorkflowState` stays separate from persisted business state.
18. An expiring condition races `context.condition` against `context.timeout`, catches Temporal's `CanceledError`, and runs the expiration Activity before assigning `.expired`.

### The worker ([worker.md](references/worker.md))

19. The worker is `worker run`: a `Worker` command group and its `Run` composition root in `<Service>/Worker/`, in serve's section order with a Worker section, opening no server and reading no verifying key.
20. It connects to its own database as `<service>_worker` (`<project>_worker` in a monolith): `CreateWorkerRole` appended at the end of `Database/Migrations.swift`, and `Postgres<Service>WorkerScope` the only conformer of its use cases' scopes, which take `input:` alone.
21. It calls other services through their internal descriptors over mTLS, with no token and no authentication interceptor; the user is a `UUID` in the input.
22. `TemporalClient.Configuration(configReader:)` and `TemporalWorker.Configuration(configReader:)` read the `temporal` scope; Temporal has its own `temporal.tls` pair and primed reloader. Mind the argument order: `TemporalClient(target:transportSecurity:configuration:logger:)`, `TemporalWorker(configuration:target:transportSecurity:activityContainers:workflows:logger:)`.
23. One `ServiceGroup` owns the worker, its Postgres client, every long-lived client its Activities use, and the reloaders.

### Tests ([testing.md](references/testing.md))

24. `<Service>WorkflowsTests` excludes `Histories`, has one parent suite carrying `.temporalTimeSkippingTestServer` with each Workflow's suite nested in an extension, and registers Activities exactly as `worker run` does.
25. Cover every branch, one non-retryable failure asserting a single attempt, Activity-name uniqueness wherever a worker registers several containers, and replay every recorded history with `WorkflowReplayer`.

## Workflow

Copy this checklist and check items off as you go:

```
Add a workflow:
- [ ] 1. Core: XWorkflowClient, XWorkflowState and XWorkflowResult, XActivityServiceProtocol with typed errors, XActivityService over the worker's use cases and capability-named provider ports
- [ ] 2. Workflows target: <Feature>Workflow with nested Input, signals, queries, timers; <Feature>Activities with one side effect each, nested Codable inputs and outputs, idempotency keys from input, explicit options, the nonRetryable helper; Temporal<Feature>WorkflowClient with deterministic IDs
- [ ] 3. Postgres: CreateWorkerRole appended at the end of Database/Migrations.swift; Postgres<Service>WorkerScope as the only conformer of the worker use cases' scopes
- [ ] 4. serve: one TemporalClient with temporal.tls and its reloader in ServiceGroup; the adapter injected into use cases; every start or signal after the transaction commits
- [ ] 5. worker run: Worker group and Run root; worker-role database; interceptor-free internal clients and provider adapters behind the Activity service; TemporalWorker with every container and Workflow; one ServiceGroup
- [ ] 6. Environment: the SDK's client and worker keys, agreeing task queues, the worker application running the service image with `worker run`
- [ ] 7. <Service>WorkflowsTests: parent suite with the server trait, a nested suite per Workflow covering every branch, recorded histories and a replay suite; swift build and swift test
```

## Completion gates

Do not call work complete until every applicable gate passes.

- `<Service>Core` imports no Temporal; `<Service>Workflows` imports no Postgres, protobuf, provider SDK, or configuration.
- Every value crossing Temporal is `Codable`; Activity payloads are nested under their container, only state and result payloads live in Core, and no Core entity is a payload.
- Every Workflow is free of side effects and nondeterminism; every side effect is one Activity with explicit options and an idempotency key derived from immutable input; no Activity name collides on the worker.
- Every start or signal happens after the local transaction committed.
- Workflow IDs are deterministic with the reuse and conflict policies their trigger calls for; signals return without waiting; queries have no side effects.
- The worker is `worker run` with its own composition root, connects as the worker role to its own database and to other services through their internal services as itself, holds no token, and owns its clients and reloaders in one `ServiceGroup`.
- The worker's environment carries the SDK's required keys and a heartbeat interval where liveness reporting is required; a missing key fails at startup.
- Every Workflow runs end to end in `<Service>WorkflowsTests`, branch by branch, and its recorded histories replay cleanly.

If a gate requires an unresolved product, consistency, or data-migration decision, stop at the safe boundary and request that decision rather than inventing behavior.
