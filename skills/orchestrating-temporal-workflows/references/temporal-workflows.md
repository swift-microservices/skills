# Temporal Workflows

Use this reference whenever a service adds or changes Temporal Workflows, Activities, clients, signals, queries, timers, or workers.

## Contents

- Module boundaries
- Workflow design
- Activity design and retries
- Workflow clients
- Transactions and durability
- Signals, queries, and state
- Timers and cancellation
- Worker composition
- Naming and file style

## Module boundaries

Add `<Service>Workflows` only when a capability requires durable waiting, retries, timers, or multi-step orchestration. Use this dependency direction:

```text
<Service>Core ← <Service>Workflows ← <Service>
```

Keep these types in Core:

- workflow-client protocols used by use cases;
- workflow state and result values;
- Activity service protocols and their typed errors;
- domain inputs and outputs used by Activities.

Keep these types in `<Service>Workflows`:

- `@Workflow` definitions;
- `@ActivityContainer` definitions;
- `TemporalXWorkflowClient` adapters;
- Temporal-specific options and error translation.

Core must not import Temporal. The Workflows target must not implement SQL, construct provider clients, read configuration, or own executable lifecycle.

## Workflow design

Use Workflow code only for deterministic orchestration. Call `WorkflowContext` for workflow time, timers, conditions, Activities, signals, and queries. Do not perform database, gRPC, HTTP, email, filesystem, environment, UUID generation, ordinary `Date()` reads, or other nondeterministic side effects directly in a Workflow.

```swift
@Workflow
package struct ReservationWorkflow {
    private var confirmed = false
    private var state = ReservationWorkflowState.inProgress

    package struct Input: Codable, Sendable {
        package let reservationId: UUID

        package init(reservationId: UUID) {
            self.reservationId = reservationId
        }
    }

    package mutating func run(
        context: WorkflowContext<Self>,
        input: Input
    ) async throws -> ReservationWorkflowResult {
        // Resolve state and execute side effects through Activities.
    }
}
```

Keep Workflow input nested under the Workflow. Make all values crossing Temporal boundaries `Codable` and `Sendable`. Return an `XWorkflowResult`, not a bare UUID or other scalar. Keep workflow state `.inProgress` until an Activity establishes a definitive `.completed`, `.expired`, or feature-specific terminal outcome. Do not add states that do not affect behavior.

Set terminal workflow state only after the corresponding Activity succeeds. Let cancellation and Activity failures propagate instead of reporting a terminal outcome prematurely.

## Activity design and retries

Put every external side effect in an Activity: the service's own database work, remote service calls, email delivery, provider operations. Give each Activity one side effect. Minting a secret and delivering it are two: issue the challenge in one Activity, send it in the next, so a failing delivery retries against the same stored digest instead of rotating the value the recipient already holds. Deleting a secret is a third, run before terminal state is assigned.

Give an Activity a distinct registration name whenever two `@ActivityContainer`s on one worker would otherwise share it. The Temporal activity name defaults to the method name, and every container registered on a worker shares one activity-name space — so a `recordPurchase` in two containers registers the same name twice and one silently overrides the other, running the wrong implementation with no error. The Swift `Activities.<Method>` type is still keyed by the Swift method, so only the registration name collides: set `@Activity(name: "RecordItemPurchase")` on one and leave the workflow call sites unchanged. Watch the worker log for `Duplicate activity registration` — it is the symptom.

Group feature Activities in one `@ActivityContainer` and inject one narrow Core service protocol:

```swift
@ActivityContainer
package struct ReservationActivities {
    private let service: any ReservationActivityServiceProtocol

    package init(service: any ReservationActivityServiceProtocol) {
        self.service = service
    }

    package struct ReserveInput: Codable, Sendable {
        package let reservationId: UUID
    }

    @Activity
    package func reserve(input: ReserveInput) async throws -> Reservation {
        try await service.reserve(reservationId: input.reservationId)
    }
}
```

Nest Activity input values under the container. Use `Id`, not `ID`, and noun-based date names, as everywhere else.

Assume every Activity can be retried after its side effect succeeds but before Temporal receives the result. Make each write retry-safe at the system that owns the side effect: unique constraints for creates, compare-and-swap updates for transitions, provider idempotency keys for email, payments, or messaging. Do not rely on Workflow fields, Activity memory, or Temporal history as the downstream idempotency mechanism.

Derive a stable, namespaced idempotency key from immutable Workflow input or a caller-owned pending-record identifier, such as `<service>-<process>-<recordId>`. Reuse the exact key on every Activity attempt; never generate a UUID inside Workflow code or per Activity retry. Pass the key through the Core Activity service port and the remote mutation contract.

The receiving service must atomically guarantee that the same key and canonical input returns the original result, including its database-generated entity id, while the same key with different input produces a permanent idempotency conflict. Map that conflict to a non-retryable Activity failure. Do not treat an idempotency key as authentication or proof that a preceding workflow step occurred.

Do not generate or preallocate an entity identifier owned by another service. Pass the caller-owned workflow or pending-record identifier through the Workflow, let the owning service return its database-generated identifier during Activity execution, then persist that returned foreign identifier through retry-safe Activity work. Do not convert `ALREADY_EXISTS` into success by looking up a business key such as email; distinct logical operations can carry identical business data.

Configure explicit Activity timeouts and retries. Leave dependency outages retryable. Translate invalid state, conflicting canonical data, and permanent consistency failures to non-retryable `ApplicationError` values at the Activity boundary. Do not catch `ActivityError` in Workflow code merely to inspect `ApplicationError.type` strings; model the operation so permanent failures can fail the Workflow cleanly.

## Workflow clients

Define the caller-facing client protocol in Core:

```swift
package protocol ReservationWorkflowClient: Sendable {
    func start(reservationId: UUID) async throws
    func confirm(reservationId: UUID) async throws
    func state(reservationId: UUID) async throws -> ReservationWorkflowState
}
```

Implement it in `<Service>Workflows` as `TemporalReservationWorkflowClient`. Store only the long-lived `TemporalClient` and task queue. Do not add custom `CallOptions` unless the established transport requires them.

Derive a deterministic workflow ID from the immutable domain identifier:

```swift
private static func workflowId(_ reservationId: UUID) -> String {
    "catalog-reservation-\(reservationId.uuidString.lowercased())"
}
```

Start with:

```swift
WorkflowOptions(
    id: Self.workflowId(reservationId),
    taskQueue: taskQueue,
    idReusePolicy: .rejectDuplicate,
    idConflictPolicy: .useExisting
)
```

These two policies already express the intent: a running Workflow returns the existing handle without error, and only a closed one rejects the start. Do not add a `catch is WorkflowAlreadyStartedError` on top — with a deterministic ID derived from a freshly created record it is unreachable, and where it can fire it reports success for a Workflow that will never run again.

Do not flatten every Temporal failure into a single `unavailable` case. Let the SDK error propagate from the adapter and classify it where the distinction is actionable.

## Transactions and durability

Never call Temporal while a PostgreSQL transaction is open. Complete the local atomic write first, then start or signal the Workflow:

```swift
let reservation = try await database.withTransaction { context in
    // Persist the complete local business state.
}
try await workflowClient.start(reservationId: reservation.id)
```

Use Temporal history as the durable execution state. Do not add a periodic worker-side database scanner, a second workflow-state table, signal-with-start, or logic that reconstructs and resumes a Workflow from persisted business state by default. Keep start and signal as distinct operations. Add cross-system repair infrastructure only when the user explicitly accepts its additional consistency model and complexity.

## Signals, queries, and state

Use a signal for a command that informs an existing Workflow. The client method returns after Temporal accepts the signal; it must not wait for Workflow completion or fetch the Workflow result:

```swift
@WorkflowSignal
package mutating func confirmed(input: Void) {
    confirmed = true
}
```

Use a query only for observation:

```swift
@WorkflowQuery
package func currentState(input: Void) throws -> ReservationWorkflowState {
    state
}
```

Signals mutate small deterministic Workflow fields. Queries return current Workflow state without causing side effects. Keep persisted business state and `XWorkflowState` separate; give each only the cases its owner needs.

A signal-only RPC cannot return an identifier that a later Activity has not created yet. Return an empty acknowledgement from that RPC and expose the generated identifier only through the owning service or a later query/result boundary. Do not pre-generate the identifier merely to populate the signal response.

## Timers and cancellation

For an expiring condition, use `WorkflowContext.timeout` with `condition`:

```swift
let confirmed = try await context.timeout(
    for: .seconds(expirationDate.timeIntervalSince(context.now))
) {
    do {
        try await context.condition { $0.confirmed }
        return true
    } catch is CanceledError {
        return false
    }
}
```

The Swift Temporal SDK timeout races its durable sleep against the body, cancels the losing child, waits for that child, and returns or rethrows the body's result. `condition` throws Temporal's `CanceledError` when the timer cancels it. Catch `CanceledError`, not Swift's `CancellationError`; do not invent a timeout error and do not add `Task.checkCancellation()` to this pattern.

On the false branch, execute the expiration Activity before assigning `.expired`:

```swift
guard confirmed else {
    try await context.executeActivity(/* expiration Activity */)
    state = .expired
    return ReservationWorkflowResult(state: state)
}
```

This preserves cancellation: if the parent Workflow was cancelled rather than merely timed out, the subsequent Temporal operation observes cancellation and throws before terminal state is assigned.

## Worker composition

The worker is `worker run` on the service executable — `Worker` a command group in `<Service>/Worker/`, `Run` a composition root of its own — never the gRPC `serve` process, and never a second product or image. The worker application runs the service's image with `worker run` as its command. It opens no server, reads no verifying key, and reads from `PostgresConfiguration` only the worker role.

**The worker reaches its own service's data directly and every other service's through its contract.** An Activity is inside the service's boundary: its input is durable workflow state rather than a caller's request, and the tables it reads are the service's own. So the worker connects to its own service's database as a role of its own — `<service>_worker`, its own secret, a `USING (true)` policy on the tenant tables (see *The roles* in the building-swift-services skill's persistence reference) — and runs the same use cases `serve` would, over a `PostgresDatabase<Postgres<Service>WorkerScope>(client:logger:)` only its composition root builds. No tenant setting is bound for it: an Activity is not a caller, and the worker role's policy admits every row. Nothing is gained by putting a network hop and a credential between a service and its own tables. Another service's rows it never touches: it calls that service's internal RPC service as itself, proved by the mTLS certificate it already presents — `CertificateAuthenticationInterceptor(authenticator: ServiceAuthenticator())` on the receiving side binds it as a `ServiceIdentity`, and the worker's own clients carry no interceptor — and that service runs the use case over its own unscoped database (see *Processes: the certificate is the credential* in the building-swift-services skill's identity-and-access reference).

**The user is data.** The worker holds no token and forwards none: a workflow can run for days, after the person who started it is gone and their token is dead. The user it acts for is named in the workflow input as a `UUID` and passed to use cases as part of `input:`, and to another service's internal RPC as a field; the receiving use case takes `service: ServiceIdentity, input:` and never a `subject: UserIdentity`. This is the first of *The three rules* in the building-swift-services skill's identity-and-access reference.

The Core Activity service is a plain struct over the use cases, in `<Service>Core/<Feature>/Activities/`:

```swift
package struct BillingActivityService: BillingActivityServiceProtocol {
    private let findPurchaseUseCase: any FindPurchaseUseCaseProtocol
    private let upsertPurchaseUseCase: any UpsertPurchaseUseCaseProtocol
    …
}
```

Its protocol is the port the Activity container takes, so the Workflows target imports neither Postgres nor the use cases. The use cases behind it take `input:` alone — they are reached by nothing but the worker — and the worker scope is the only scope that conforms to their scope protocols, so `serve` cannot build them by accident.

The worker composition root owns:

- configuration and logging, reading from the shared `PostgresConfiguration` the worker role alone;
- one `PostgresClient` as the worker role, and the `PostgresDatabase<Postgres<Service>WorkerScope>` over it;
- long-lived gRPC clients to the internal services its Activities call, carrying no interceptor;
- long-lived provider clients used by Activities;
- the use cases, the concrete Core Activity service over them, and the consumer adapters over the internal-service clients;
- one `TemporalWorker` with explicit workflow definitions and Activity containers;
- one `ServiceGroup` containing the worker, the Postgres client, and every other long-lived dependency.

Configure the client and the worker from the SDK's own configuration readers — `TemporalClient.Configuration(configReader:)` and `TemporalWorker.Configuration(configReader:)` over the `temporal` scope (see *Temporal worker composition root* in the building-swift-services skill's composition reference) — with the namespace named after the deployment environment, and the same transport security in both: the stack's mTLS client factory when the Temporal server runs in the stack, TLS with the system trust roots and an API key when it is a managed engine (see *Transport security factories* in the same reference). The worker *requires* `TEMPORAL_WORKER_NAMESPACE`, `_TASKQUEUE`, `_BUILDID`, `_CLIENT_IDENTITY`, and `_CLIENT_INSTRUMENTATION_SERVERHOSTNAME`, and should set `_HEARTBEATINTERVALMS` — the SDK's default disables liveness heartbeats. Manage the client and worker with graceful shutdown signals. Do not run a cancellation-aware reconciliation service beside the worker.

## Naming and file style

```text
Sources/<Service>Workflows/<Feature>/
  <Feature>Workflow.swift
  <Feature>Activities.swift
  Temporal<Feature>WorkflowClient.swift
```

Use `package` access across targets, `private` mutable Workflow fields, nested `Input` values, and nested Activity input values. Preserve the conditional Foundation imports and import ordering. Name identifiers `xId`, Workflow types `XWorkflow`, Activity containers `XActivities`, Core ports `XWorkflowClient`, and Temporal implementations `TemporalXWorkflowClient`.
