# Workflow clients

How a use case starts, signals, and queries a Workflow: the Core port, the Temporal adapter, workflow IDs and their policies, event-triggered workflows, and the order of commits and starts. Workflows and payloads are in [workflows.md](workflows.md); Activities are in [activities.md](activities.md).

## Contents

- [Workflow clients](#workflow-clients)
- [Event-triggered workflows](#event-triggered-workflows)
- [Transactions and durability](#transactions-and-durability)
- [Signals, queries, and state](#signals-queries-and-state)

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
- The execution timeout bounds the run, and its Activities take the bounded options in [Timeouts and retries](activities.md#timeouts-and-retries), so a stuck run fails and the provider's redelivery retries it.
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
