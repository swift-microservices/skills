# Workflows

Where Temporal code lives, what a Workflow may do, how payloads, Activities, clients, signals, queries, and timers are written. The examples are one feature, a catalog service's reservation: hold an item, wait for confirmation until the hold expires, then confirm or release it.

## Contents

- [Module boundaries](#module-boundaries)
- [The Workflow](#the-workflow)
- [Child workflows](#child-workflows)
- [Payloads](#payloads)
- [Activities](#activities)
- [Timeouts and retries](#timeouts-and-retries)
- [Provider leaves](#provider-leaves)
- [Workflow clients](#workflow-clients)
- [Event-triggered workflows](#event-triggered-workflows)
- [Transactions and durability](#transactions-and-durability)
- [Signals, queries, and state](#signals-queries-and-state)
- [Timers and cancellation](#timers-and-cancellation)
- [Naming and file layout](#naming-and-file-layout)

## Module boundaries

```text
<Service>Core ← <Service>Workflows ← <Service>
```

| Core, without importing Temporal | `<Service>Workflows` |
| --- | --- |
| `XWorkflowClient`, the port use cases call | `@Workflow` definitions |
| `XWorkflowState`, `XWorkflowResult`, the types they hold (`Codable`) | `@ActivityContainer` definitions, with every Activity input and output nested |
| `XActivityServiceProtocol`, its typed errors, and `XActivityService` over the worker's use cases | `TemporalXWorkflowClient` adapters |
| provider ports such as `PasswordHasher` or `ConfirmationEmailSender` | Temporal options and error translation |

The Workflows target implements no SQL, constructs no client, reads no configuration, and owns no lifecycle. Its dependencies are Core, `Temporal`, and `Logging` when a Workflow logs:

```swift
.target(
    name: "CatalogWorkflows",
    dependencies: [
        "CatalogCore",
        .product(name: "Logging", package: "swift-log"),
        .product(name: "Temporal", package: "swift-temporal-sdk"),
    ],
    swiftSettings: swiftSettings
),
```

**The Swift 6.3 import trap.** Under `InternalImportsByDefault` an Activity container file needs `package import Temporal`, because the members `@ActivityContainer` expands are `package` and name Temporal types. Swift 6.3 does not count macro-expanded declarations as uses of an import, so it reports that import unused, an error wherever warnings are errors. Give each container file one `package` declaration of its own whose signature names a Temporal type; the `nonRetryable` helper in [Activities](#activities) is that declaration. Workflow and client files need no workaround: `WorkflowContext<Self>` and `TemporalClient` already appear in their `package` signatures.

## The Workflow

A Workflow may compute, wait, and decide. It reads the time as `context.now`, logs through `context.logger`, and reaches Activities, timers, conditions, signals, and queries through `WorkflowContext`. No database, gRPC, HTTP, email, filesystem, environment, `UUID()`, `Date()`, `Date.now`, or random source.

```swift
package import CatalogCore
import Logging
package import Temporal

#if canImport(FoundationEssentials)
package import FoundationEssentials
#else
package import Foundation
#endif

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
        // Local work that can wait out an outage: unlimited attempts, each one bounded.
        let options = ActivityOptions(
            startToCloseTimeout: .seconds(30),
            retryPolicy: RetryPolicy(
                initialInterval: .seconds(1),
                backoffCoefficient: 2,
                maximumInterval: .seconds(30),
                maximumAttempts: 0
            )
        )

        let reservation = try await context.executeActivity(
            ReservationActivities.Activities.Reserve.self,
            options: options,
            input: ReservationActivities.ReserveInput(reservationId: input.reservationId)
        )

        let wasConfirmed = try await context.timeout(
            for: .seconds(reservation.expirationDate.timeIntervalSince(context.now))
        ) {
            do {
                try await context.condition { $0.confirmed }
                return true
            } catch is CanceledError {
                return false
            }
        }

        guard wasConfirmed else {
            try await context.executeActivity(
                ReservationActivities.Activities.Release.self,
                options: options,
                input: ReservationActivities.ReleaseInput(reservationId: input.reservationId)
            )
            state = .expired
            context.logger.info("Reservation expired", metadata: ["reservationId": "\(input.reservationId)"])
            return ReservationWorkflowResult(reservationId: input.reservationId, state: state)
        }

        let confirmation = try await context.executeActivity(
            ReservationActivities.Activities.Confirm.self,
            options: options,
            input: ReservationActivities.ConfirmInput(reservationId: input.reservationId)
        )
        state = .confirmed(orderId: confirmation.orderId)

        // Best effort after the terminal state: a few attempts, then the run fails, and the
        // failed run is the record that the email was lost. The order stands either way.
        try await context.executeActivity(
            ReservationActivities.Activities.SendConfirmation.self,
            options: ActivityOptions(
                startToCloseTimeout: .seconds(30),
                retryPolicy: RetryPolicy(
                    initialInterval: .seconds(1),
                    backoffCoefficient: 2,
                    maximumInterval: .seconds(30),
                    maximumAttempts: 5
                )
            ),
            input: ReservationActivities.SendConfirmationInput(
                reservationId: input.reservationId,
                orderId: confirmation.orderId
            )
        )

        return ReservationWorkflowResult(reservationId: input.reservationId, state: state)
    }

    @WorkflowSignal
    package mutating func confirm(input: Void) {
        confirmed = true
    }

    @WorkflowQuery
    package func currentState(input: Void) throws -> ReservationWorkflowState {
        state
    }
}
```

- `@Activity func reserve` is called as `ReservationActivities.Activities.Reserve.self`; `@WorkflowSignal func confirm` is `ReservationWorkflow.Confirm`, `@WorkflowQuery func currentState` is `ReservationWorkflow.CurrentState`.
- State stays `.inProgress` until the Activity that establishes a terminal outcome succeeds. Cancellation and Activity failures propagate; nothing reports a terminal state early. A step that matters less than the outcome runs after the state is assigned, with bounded attempts.
- Return an `XWorkflowResult` when a caller awaits or queries the outcome. A fire-and-forget Workflow nobody awaits, such as one a webhook starts, returns `Void`. Never return a bare scalar: a result is a payload, and a struct can gain a field.
- Add no states that do not change behavior.

## Child workflows

Start a child when a step is itself a Workflow another trigger also starts, so the two share one definition and one history shape. Derive its ID from the parent's immutable input, bound it with an execution timeout, and register it on the same worker:

```swift
try await context.executeChildWorkflow(
    SubscriptionWorkflow.self,
    options: ChildWorkflowOptions(
        id: "billing-subscription-\(subscriptionId)-\(input.sessionId)",
        retryPolicy: RetryPolicy(maximumAttempts: 1),
        executionTimeout: .seconds(30 * 60)
    ),
    input: SubscriptionWorkflow.Input(subscriptionId: subscriptionId)
)
```

The child's Activities retry on their own policies; `maximumAttempts: 1` keeps the child from rerunning them as a whole. A parent that closes terminates the child by default (`parentClosePolicy: .terminate`).

## Payloads

A payload is any value Temporal carries: Workflow input and result, Activity input and output, signal, query, and update input and output. Temporal writes each one into history and decodes it again on every replay, so a payload is a stored contract.

**Every payload is `Codable` and `Sendable`, and so is every type it holds.** The SDK constrains payloads to `Sendable` alone and checks `Codable` at runtime, so a missing conformance compiles and fails the first Workflow that converts the value, on every attempt. Never remove `Codable` from a type because the build still passes; find out first whether it crosses Temporal.

| Payload | Declared |
| --- | --- |
| Workflow `Input`; signal, query, and update inputs | nested under the `@Workflow` |
| Activity inputs and outputs | nested under the `@ActivityContainer` |
| `XWorkflowState`, `XWorkflowResult`, and the types they hold | Core, because the `XWorkflowClient` port returns them to use cases |
| a scalar: `UUID`, `String`, `Bool`, an optional of one | nowhere; it is already `Codable` |

No other Core type is `Codable` on Temporal's account.

**Never a domain model.** The Activity-service port takes and returns Core types; the Activity maps what it returns into a nested output holding only the fields the Workflow reads (`Confirmation(orderId:)`, not `Order`). A changed model then cannot break the replay of a running Workflow, and history keeps no personal data the Workflow never read. A Core enum a payload needs is mirrored as a nested enum with the same raw values and mapped by an initializer:

```swift
package struct RecordInput: Codable, Sendable {
    package let status: Status

    package enum Status: String, Codable, Sendable {
        case active
        case billingRetry = "billing_retry"
    }
}

extension OrderStatus {
    fileprivate init(_ status: ReservationActivities.RecordInput.Status) {
        switch status {
        case .active: self = .active
        case .billingRetry: self = .billingRetry
        }
    }
}
```

**Change a payload the way a wire format changes.** A running Workflow replays its recorded payloads into the new type, and the decoder ignores unknown keys but rejects a missing non-optional key or an unknown enum case:

- add a field as an optional, or give it a default in a custom `init(from:)`;
- removing a field is safe; renaming one is a removal plus a required addition, which is not;
- never remove or rename an enum case, or change its associated values, while a history may hold it;
- a change that cannot follow these rules waits until every Workflow started under the old shape has closed, or ships behind `context.patch(_:)`.

A `Date` crosses Temporal at whole-second precision. Never compare a round-tripped date for equality or use one as a key.

## Activities

Assume every Activity runs again after its side effect succeeded. Give each one side effect: issuing a secret, delivering it, and deleting it are three Activities, so a failing delivery retries against the same stored digest instead of rotating the value the recipient already holds.

A feature's Activities share one `@ActivityContainer` that takes one Core Activity-service protocol. Everything an Activity reaches, the worker's use cases, a provider, another service's internal contract, sits behind that service in Core terms: provider ports and consumer adapters are injected into `XActivityService` by the worker's composition root, never into the container.

```swift
package import CatalogCore
package import Temporal

#if canImport(FoundationEssentials)
package import FoundationEssentials
#else
package import Foundation
#endif

@ActivityContainer
package struct ReservationActivities {
    private let service: any ReservationActivityServiceProtocol

    package init(service: any ReservationActivityServiceProtocol) {
        self.service = service
    }

    /// A permanent failure: the Workflow fails instead of retrying the Activity.
    ///
    /// `package`, so this file's `package import Temporal` has a use Swift 6.3 counts.
    package static func nonRetryable(_ message: String, type: String) -> ApplicationError {
        ApplicationError(message: message, type: type, isNonRetryable: true)
    }

    package struct ReserveInput: Codable, Sendable {
        package let reservationId: UUID
    }

    package struct Reserved: Codable, Sendable {
        package let expirationDate: Date
    }

    package struct ReleaseInput: Codable, Sendable {
        package let reservationId: UUID
    }

    package struct ConfirmInput: Codable, Sendable {
        package let reservationId: UUID
    }

    package struct Confirmation: Codable, Sendable {
        package let orderId: UUID
    }

    package struct SendConfirmationInput: Codable, Sendable {
        package let reservationId: UUID
        package let orderId: UUID
    }

    @Activity
    package func reserve(input: ReserveInput) async throws -> Reserved {
        do {
            let reservation = try await service.reserve(reservationId: input.reservationId)
            return Reserved(expirationDate: reservation.expirationDate)
        } catch ReservationActivityServiceError.invalidState {
            throw Self.nonRetryable("The reservation cannot be held from its current state.", type: "InvalidReservationState")
        }
    }

    @Activity
    package func release(input: ReleaseInput) async throws {
        do {
            try await service.release(reservationId: input.reservationId)
        } catch ReservationActivityServiceError.alreadyConfirmed {
            throw Self.nonRetryable("The reservation was confirmed before it could be released.", type: "ReservationAlreadyConfirmed")
        }
    }

    @Activity
    package func confirm(input: ConfirmInput) async throws -> Confirmation {
        do {
            let order = try await service.confirm(reservationId: input.reservationId)
            return Confirmation(orderId: order.id)
        } catch ReservationActivityServiceError.invalidState {
            throw Self.nonRetryable("The reservation cannot be confirmed from its current state.", type: "InvalidReservationState")
        }
    }

    @Activity
    package func sendConfirmation(input: SendConfirmationInput) async throws {
        try await service.sendConfirmation(
            reservationId: input.reservationId,
            orderId: input.orderId,
            idempotencyKey: "catalog-reservation-confirmation-\(input.reservationId.uuidString.lowercased())"
        )
    }
}
```

The Core side is a protocol with an `Equatable` typed error, and a plain struct over the use cases the worker runs and the provider ports it calls, in `<Service>Core/<Feature>/Activities/`:

```swift
package protocol ReservationActivityServiceProtocol: Sendable {
    func reserve(reservationId: UUID) async throws -> Reservation
    func release(reservationId: UUID) async throws
    func confirm(reservationId: UUID) async throws -> Order
    func sendConfirmation(reservationId: UUID, orderId: UUID, idempotencyKey: String) async throws
}

package struct ReservationActivityService: ReservationActivityServiceProtocol {
    private let reserveUseCase: any ReserveItemUseCaseProtocol
    private let releaseUseCase: any ReleaseReservationUseCaseProtocol
    private let confirmUseCase: any ConfirmReservationUseCaseProtocol
    private let confirmationEmailSender: any ConfirmationEmailSender
    // init and members: each maps its use case's typed error into ReservationActivityServiceError
}
```

The use cases behind it take `input:` alone and run over the worker's database (see [worker.md](worker.md#the-worker-role-and-scope)).

**Idempotency lives with the owner of the side effect.** Make every write retry-safe where it is owned: a unique constraint for a create, a compare-and-swap for a transition, a provider's idempotency key for email, payments, or messaging. Workflow history is never the deduplication mechanism.

- Derive a stable, namespaced key from immutable Workflow input or a caller-owned pending-record id, `<service>-<process>-<recordId>`, in the Activity or the Workflow, and reuse it on every attempt. Never mint a UUID in Workflow code or per attempt.
- Pass the key through the Activity-service port and on through the provider port or the remote mutation contract, so no adapter invents one.
- The receiver returns the original result, including its database-generated id, for the same key and canonical input, and a permanent conflict for the same key with different input; map that conflict to a non-retryable failure. A key is not authentication or proof that an earlier step ran.
- Never preallocate an id another service owns: pass the caller-owned id, receive the owner's generated id from the Activity, and persist it retry-safely. Never turn `ALREADY_EXISTS` into success by looking up a business key such as an email.

**Translate permanent failures at the Activity boundary.** Invalid state, conflicting canonical input, and permanent consistency failures become `nonRetryable` errors; dependency outages stay retryable. Workflow code never catches `ActivityError` to inspect `ApplicationError.type` strings; model the operation so a permanent failure fails the Workflow cleanly.

Every container on a worker shares one Activity-name space, and a name defaults to the method name. When two containers would register the same name, set `@Activity(name: "RecordLicensePurchase")` on one; call sites keep using the Swift type. The uniqueness test is in [testing.md](testing.md#activity-names-are-unique).

## Timeouts and retries

Every `executeActivity` passes explicit `ActivityOptions`. Choose by whether the effect can wait out a dependency outage:

| The effect | Options |
| --- | --- |
| can wait: a local write, an email the person is waiting for inside a long window | `startToCloseTimeout: .seconds(30)`, `RetryPolicy(initialInterval: .seconds(1), backoffCoefficient: 2, maximumInterval: .seconds(30), maximumAttempts: 0)`: unlimited attempts, each bounded, so the Workflow resumes when the dependency does |
| should not wait: a provider call in an event-triggered Workflow, or anything a stale attempt makes worse | `ActivityOptions(scheduleToCloseTimeout: .seconds(5 * 60), startToCloseTimeout: .seconds(30), retryPolicy: RetryPolicy(maximumAttempts: 5))`, three to five minutes in total; the run fails, and a redelivered trigger starts it again |
| best effort after the terminal state | five attempts with backoff, as in [The Workflow](#the-workflow) |

With unlimited attempts, every permanent failure must be non-retryable, or the Workflow retries it forever. An Activity that runs longer than a minute heartbeats and sets `heartbeatTimeout`, so a dead worker's attempt is retried without waiting out `startToCloseTimeout`. Keep an event-triggered Workflow's execution timeout above the sum of its Activities' `scheduleToCloseTimeout`s.

## Provider leaves

A provider SDK lives in its own adapter target (`<Service>Resend`, `<Service>Stripe`, `<Service>Bcrypt`) implementing a Core port, as the building-swift-services skill's [service-package.md](../../building-swift-services/references/service-package.md) lays out.

- Name the port for the capability, not the vendor: `PasswordHasher`, `VerificationEmailSender`, `PaymentGateway`. The adapter carries the vendor name: `ResendVerificationEmailSender`.
- A port that mutates takes the idempotency key as a parameter; the adapter sends it as the provider's idempotency key or header.
- Webhook signature verification is a port too, `verifyEvent(payload:signature:)` on the gateway or its own `PaymentEventVerifier`, so the use case that receives the webhook stays testable and vendor-free.
- The adapter maps provider failures to the port's typed errors. Permanent rejections, an invalid request, an object that does not exist, an idempotency-key conflict, a failed signature check, become errors the Activity turns non-retryable. Rate limits, 5xx responses, timeouts, and connection failures stay retryable.

## Workflow clients

The use cases call a Core protocol keyed by the domain id:

```swift
package protocol ReservationWorkflowClient: Sendable {
    func start(reservationId: UUID) async throws
    func confirm(reservationId: UUID) async throws
    func state(reservationId: UUID) async throws -> ReservationWorkflowState
}
```

Its Temporal implementation holds only the long-lived `TemporalClient` and the task queue:

```swift
package import CatalogCore
package import Temporal

#if canImport(FoundationEssentials)
package import FoundationEssentials
#else
package import Foundation
#endif

package struct TemporalReservationWorkflowClient: ReservationWorkflowClient {
    private let client: TemporalClient
    private let taskQueue: String

    package init(client: TemporalClient, taskQueue: String) {
        self.client = client
        self.taskQueue = taskQueue
    }

    package func start(reservationId: UUID) async throws {
        _ = try await client.startWorkflow(
            type: ReservationWorkflow.self,
            options: WorkflowOptions(
                id: workflowId(for: reservationId),
                taskQueue: taskQueue,
                idReusePolicy: .rejectDuplicate,
                idConflictPolicy: .useExisting
            ),
            input: ReservationWorkflow.Input(reservationId: reservationId)
        )
    }

    package func confirm(reservationId: UUID) async throws {
        try await handle(for: reservationId).signal(signalType: ReservationWorkflow.Confirm.self)
    }

    package func state(reservationId: UUID) async throws -> ReservationWorkflowState {
        try await handle(for: reservationId).query(queryType: ReservationWorkflow.CurrentState.self)
    }

    private func handle(for reservationId: UUID) -> WorkflowHandle<ReservationWorkflow> {
        client.workflowHandle(type: ReservationWorkflow.self, id: workflowId(for: reservationId))
    }

    private func workflowId(for reservationId: UUID) -> String {
        "catalog-reservation-\(reservationId.uuidString.lowercased())"
    }
}
```

An entity-lifetime Workflow, one run for the life of a record, takes its ID from the immutable domain id, `<service>-<feature>-<id>`, with `.rejectDuplicate` and `.useExisting`: a start for a running Workflow returns its handle, and a start for a closed one is rejected. Do not catch `WorkflowAlreadyStartedError` on top; where it can fire, it reports success for a Workflow that will never run again.

Let SDK errors propagate from the adapter and classify them where the distinction is actionable; never funnel every Temporal failure into one `.unavailable` case. Add no custom `CallOptions`.

## Event-triggered workflows

A provider webhook delivers an event at least once, possibly out of order. The Workflow it starts is keyed by the event, not the entity's lifetime:

```swift
package func startFulfillment(sessionId: String, eventId: String) async throws {
    _ = try await client.startWorkflow(
        type: FulfillmentWorkflow.self,
        options: WorkflowOptions(
            id: "billing-fulfillment-\(sessionId)-\(eventId)",
            taskQueue: taskQueue,
            executionTimeOut: .seconds(60 * 60),
            idReusePolicy: .allowDuplicateFailedOnly,
            idConflictPolicy: .useExisting
        ),
        input: FulfillmentWorkflow.Input(sessionId: sessionId)
    )
}
```

- The ID is `<service>-<feature>-<entity>-<eventId>`. A redelivered event lands on the running or completed run; a run that failed may start again on the next delivery, which `.allowDuplicateFailedOnly` allows.
- The execution timeout bounds the run, and its Activities take the bounded options in [Timeouts and retries](#timeouts-and-retries), so a stuck run fails and the provider's redelivery retries it.
- The webhook payload is a trigger, not data. The input carries the entity id; the first Activity re-fetches the live object from the provider, and the Workflow decides on that, so a stale or out-of-order event decides nothing.
- The effect is idempotent at its owner, keyed by the entity (`sourceId: session.id`), so two runs for two events about one entity converge. A grant in another service goes through that service's internal contract with the same key.
- The receiving use case verifies the signature through its port, starts the Workflow, and returns; it opens no transaction. A failed start fails the request, and the provider redelivers.

## Transactions and durability

Commit local database work, then start or signal. Never call Temporal inside `withTransaction`:

```swift
let reservation = try await database.withTransaction { context in
    // Persist the complete local business state.
}
try await workflowClient.start(reservationId: reservation.id)
```

Temporal history is the workflow state. Keep start and signal distinct: no signal-with-start, no second workflow-state table, no scanner that resumes Workflows from business rows, and no periodic reconciler, unless the user explicitly accepts that consistency model.

## Signals, queries, and state

A signal is a command: it sets a small deterministic field, and the client returns once Temporal accepted it, never waiting for completion or fetching the result. A query observes and has no side effect. Keep `XWorkflowState` separate from persisted business state, each with only the cases its owner needs.

A signal-only RPC cannot return an id a later Activity has not created yet. Return an empty acknowledgement and expose the generated id through the owning service or a later query or result; never pre-generate it to fill the response.

## Timers and cancellation

For an expiring condition, race `context.condition` against `context.timeout`, as in [The Workflow](#the-workflow). The timer cancels the condition with Temporal's `CanceledError`; catch that, not Swift's `CancellationError`, and add no `Task.checkCancellation()` or invented timeout error.

On the timed-out branch, run the expiration Activity before assigning `.expired`. If the Workflow itself was cancelled rather than timed out, that Activity call throws and no terminal state is written.

## Naming and file layout

```text
Sources/<Service>Workflows/<Feature>/
  <Feature>Workflow.swift
  <Feature>Activities.swift
  Temporal<Feature>WorkflowClient.swift
Sources/<Service>Core/<Feature>/
  Activities/<Feature>ActivityService.swift, …Protocol.swift, …Error.swift
  Workflow/<Feature>WorkflowClient.swift, <Feature>WorkflowState.swift, <Feature>WorkflowResult.swift
```

`XWorkflow`, `XActivities`, `XWorkflowClient` (Core), `TemporalXWorkflowClient`, `XActivityService` and `XActivityServiceProtocol` (Core). Workflow IDs are lowercase, `<service>-<feature>-<id>`; a monolith prefixes `<project>-<module>-` (see [worker.md](worker.md#a-monolith)). Use `package` access across targets, `private` mutable Workflow fields, and the FoundationEssentials conditional import of the writing-swift-server-code skill's [Foundation policy](../../writing-swift-server-code/references/foundation.md).
