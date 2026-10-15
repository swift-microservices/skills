# Workflows

Where Temporal code lives, what a Workflow may do, how payloads, Activities, clients, signals, queries, and timers are written. The examples are one feature, a catalog service's reservation: hold an item, wait for confirmation until the hold expires, then confirm or release it.

## Contents

- [Module boundaries](#module-boundaries)
- [The Workflow](#the-workflow)
- [Child workflows](#child-workflows)
- [Payloads](#payloads)
- [Activities](activities.md#activities)
- [Timeouts and retries](activities.md#timeouts-and-retries)
- [Provider leaves](activities.md#provider-leaves)
- [Workflow clients](workflow-clients.md#workflow-clients)
- [Event-triggered workflows](workflow-clients.md#event-triggered-workflows)
- [Transactions and durability](workflow-clients.md#transactions-and-durability)
- [Signals, queries, and state](workflow-clients.md#signals-queries-and-state)
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

**The Swift 6.3 import trap.** Under `InternalImportsByDefault` an Activity container file needs `package import Temporal`, because the members `@ActivityContainer` expands are `package` and name Temporal types. Swift 6.3 does not count macro-expanded declarations as uses of an import, so it reports that import unused, an error wherever warnings are errors. Give each container file one `package` declaration of its own whose signature names a Temporal type; the `nonRetryable` helper in [Activities](activities.md#activities) is that declaration. Workflow and client files need no workaround: `WorkflowContext<Self>` and `TemporalClient` already appear in their `package` signatures.

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
