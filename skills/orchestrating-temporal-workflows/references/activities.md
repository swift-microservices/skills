# Activities

One retry-safe Activity per side effect: containers, the Activity-service port, idempotency keys, options, retries, and provider leaves. Module boundaries, Workflows, and payloads are in [workflows.md](workflows.md); clients and signals are in [workflow-clients.md](workflow-clients.md).

## Contents

- [Activities](#activities)
- [Timeouts and retries](#timeouts-and-retries)
- [Provider leaves](#provider-leaves)

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
| best effort after the terminal state | five attempts with backoff, as in [The Workflow](workflows.md#the-workflow) |

With unlimited attempts, every permanent failure must be non-retryable, or the Workflow retries it forever. An Activity that runs longer than a minute heartbeats and sets `heartbeatTimeout`, so a dead worker's attempt is retried without waiting out `startToCloseTimeout`. Keep an event-triggered Workflow's execution timeout above the sum of its Activities' `scheduleToCloseTimeout`s.

## Provider leaves

A provider SDK lives in its own adapter target (`<Service>Resend`, `<Service>Stripe`, `<Service>Bcrypt`) implementing a Core port, as the building-swift-services skill's [service-package.md](../../building-swift-services/references/service-package.md) lays out.

- Name the port for the capability, not the vendor: `PasswordHasher`, `VerificationEmailSender`, `PaymentGateway`. The adapter carries the vendor name: `ResendVerificationEmailSender`.
- A port that mutates takes the idempotency key as a parameter; the adapter sends it as the provider's idempotency key or header.
- Webhook signature verification is a port too, `verifyEvent(payload:signature:)` on the gateway or its own `PaymentEventVerifier`, so the use case that receives the webhook stays testable and vendor-free.
- The adapter maps provider failures to the port's typed errors. Permanent rejections, an invalid request, an object that does not exist, an idempotency-key conflict, a failed signature check, become errors the Activity turns non-retryable. Rate limits, 5xx responses, timeouts, and connection failures stay retryable.
