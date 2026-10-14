#!/bin/bash
# Lays down an abridged catalog service with a Temporal workflow for the reviewer to audit.
set -euo pipefail
mkdir -p Sources/CatalogCore/Reservations/UseCases/CreateReservation Sources/CatalogCore/Reservations/Activities \
  Sources/CatalogWorkflows/Reservation Sources/Catalog/Worker Sources/Catalog/Serve Sources/Catalog/Database
cat > Package.swift <<'SWIFT'
// swift-tools-version: 6.3
import PackageDescription

let swiftSettings: [SwiftSetting] = [
    .enableUpcomingFeature("ExistentialAny"),
    .enableUpcomingFeature("MemberImportVisibility"),
    .enableUpcomingFeature("InternalImportsByDefault"),
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
]

let package = Package(
    name: "acme-catalog",
    platforms: [.macOS(.v15)],
    products: [.executable(name: "catalog", targets: ["Catalog"])],
    dependencies: [
        .package(url: "https://github.com/swift-microservices/swift-persistence.git", from: "0.2.0"),
        .package(url: "https://github.com/swift-microservices/swift-persistence-postgres.git", from: "0.3.0"),
        .package(url: "https://github.com/acme/acme-core.git", from: "0.1.0"),
        .package(url: "https://github.com/apple/swift-temporal-sdk.git", from: "0.6.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.15.0"),
        .package(url: "https://github.com/swift-server/swift-service-lifecycle.git", from: "2.8.0"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.6.0"),
    ],
    targets: [
        .target(name: "CatalogCore", dependencies: [
            .product(name: "Persistence", package: "swift-persistence"),
            .product(name: "AcmeAuthentication", package: "acme-core"),
            .product(name: "Logging", package: "swift-log"),
        ], swiftSettings: swiftSettings),
        .target(name: "CatalogWorkflows", dependencies: [
            "CatalogCore",
            .product(name: "Temporal", package: "swift-temporal-sdk"),
            .product(name: "Logging", package: "swift-log"),
        ], swiftSettings: swiftSettings),
        .executableTarget(name: "Catalog", dependencies: [
            "CatalogCore", "CatalogWorkflows",
            .product(name: "PersistencePostgres", package: "swift-persistence-postgres"),
            .product(name: "Temporal", package: "swift-temporal-sdk"),
            .product(name: "ServiceLifecycle", package: "swift-service-lifecycle"),
            .product(name: "ArgumentParser", package: "swift-argument-parser"),
            .product(name: "Logging", package: "swift-log"),
        ], swiftSettings: swiftSettings),
    ],
    swiftLanguageModes: [.v6]
)
SWIFT
cat > Sources/CatalogCore/Reservations/ReservationWorkflowClient.swift <<'SWIFT'
#if canImport(FoundationEssentials)
package import FoundationEssentials
#else
package import Foundation
#endif

/// Starts and observes the reservation workflow without exposing Temporal to Core.
package protocol ReservationWorkflowClient: Sendable {
    func startReservation(reservationId: UUID) async throws
    func confirmReservation(reservationId: UUID) async throws
}

package enum ReservationWorkflowState: Codable, Equatable, Sendable {
    case inProgress
    case confirmed(orderId: UUID)
    case expired
}

package struct ReservationWorkflowResult: Codable, Equatable, Sendable {
    package let reservationId: UUID
    package let state: ReservationWorkflowState

    package init(reservationId: UUID, state: ReservationWorkflowState) {
        self.reservationId = reservationId
        self.state = state
    }
}
SWIFT
cat > Sources/CatalogCore/Reservations/UseCases/CreateReservation/CreateReservationUseCase.swift <<'SWIFT'
package import AcmeAuthentication
package import Logging
package import Persistence

package struct CreateReservationUseCase<DatabaseType: Database>: CreateReservationUseCaseProtocol where DatabaseType.Scope: CreateReservationUseCaseScope {
    private let database: DatabaseType
    private let workflowClient: any ReservationWorkflowClient
    private let logger: Logger

    package init(database: DatabaseType, workflowClient: any ReservationWorkflowClient, logger: Logger) {
        self.database = database
        self.workflowClient = workflowClient
        self.logger = logger
    }

    package func callAsFunction(subject: UserIdentity, input: CreateReservationUseCaseInput) async throws(CreateReservationUseCaseError) -> Reservation {
        do {
            let reservation = try await database.withTransaction { scope in
                let reservation = try await scope.reservationRepository.create(
                    CreateReservationCommand(userId: subject.userId, itemId: input.itemId)
                )
                try await workflowClient.startReservation(reservationId: reservation.id)
                return reservation
            }
            logger.info("Reservation created", metadata: ["reservationId": "\(reservation.id)"])
            return reservation
        } catch {
            logger.error("Reservation create failed: unknown error", metadata: ["error": "\(String(reflecting: error))"])
            throw .unknown
        }
    }
}
SWIFT
cat > Sources/CatalogCore/Reservations/Activities/ReservationActivityService.swift <<'SWIFT'
#if canImport(FoundationEssentials)
package import FoundationEssentials
#else
package import Foundation
#endif

package enum ReservationActivityServiceError: Error, Equatable {
    case invalidState
}

package protocol ReservationActivityServiceProtocol: Sendable {
    func release(reservationId: UUID) async throws
    func confirm(reservationId: UUID, idempotencyKey: String) async throws -> Order
}
SWIFT
cat > Sources/CatalogWorkflows/Reservation/ReservationWorkflow.swift <<'SWIFT'
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
        package let expirationDate: Date
    }

    package mutating func run(context: WorkflowContext<Self>, input: Input) async throws -> ReservationWorkflowResult {
        let options = ActivityOptions(
            startToCloseTimeout: .seconds(30),
            retryPolicy: RetryPolicy(initialInterval: .seconds(1), backoffCoefficient: 2, maximumInterval: .seconds(30), maximumAttempts: 0)
        )

        let wasConfirmed = try await context.timeout(for: .seconds(input.expirationDate.timeIntervalSince(Date.now))) {
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
            return ReservationWorkflowResult(reservationId: input.reservationId, state: state)
        }

        let confirmation = try await context.executeActivity(
            ReservationActivities.Activities.Confirm.self,
            options: options,
            input: ReservationActivities.ConfirmInput(reservationId: input.reservationId)
        )
        state = .confirmed(orderId: confirmation.orderId)
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
SWIFT
cat > Sources/CatalogWorkflows/Reservation/ReservationActivities.swift <<'SWIFT'
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

    /// `package`, so this file's `package import Temporal` has a use Swift 6.3 counts.
    package static func nonRetryable(_ message: String, type: String) -> ApplicationError {
        ApplicationError(message: message, type: type, isNonRetryable: true)
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

    @Activity
    package func release(input: ReleaseInput) async throws {
        try await service.release(reservationId: input.reservationId)
    }

    @Activity
    package func confirm(input: ConfirmInput) async throws -> Confirmation {
        do {
            let order = try await service.confirm(
                reservationId: input.reservationId,
                idempotencyKey: "catalog-reservation-confirm-\(UUID().uuidString.lowercased())"
            )
            return Confirmation(orderId: order.id)
        } catch ReservationActivityServiceError.invalidState {
            throw Self.nonRetryable("The reservation cannot be confirmed from its current state.", type: "InvalidReservationState")
        }
    }
}
SWIFT
cat > Sources/CatalogWorkflows/Reservation/TemporalReservationWorkflowClient.swift <<'SWIFT'
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

    package func startReservation(reservationId: UUID) async throws {
        _ = try await client.startWorkflow(
            type: ReservationWorkflow.self,
            options: WorkflowOptions(
                id: Self.workflowId(reservationId),
                taskQueue: taskQueue,
                idReusePolicy: .rejectDuplicate,
                idConflictPolicy: .useExisting
            ),
            input: ReservationWorkflow.Input(reservationId: reservationId, expirationDate: .now.addingTimeInterval(15 * 60))
        )
    }

    package func confirmReservation(reservationId: UUID) async throws {
        let handle = client.workflowHandle(type: ReservationWorkflow.self, id: Self.workflowId(reservationId))
        try await handle.signal(signalType: ReservationWorkflow.Confirm.self)
    }

    private static func workflowId(_ reservationId: UUID) -> String {
        "catalog-reservation-\(reservationId.uuidString.lowercased())"
    }
}
SWIFT
cat > Sources/Catalog/Worker/Run.swift <<'SWIFT'
// Worker composition root, abridged for the fixture: configuration readers, logging, and the
// reloader construction are omitted. Shown: the worker's own database role and lifecycle.
//
// let postgres = try PostgresConfiguration(config: config.scoped(to: "postgres"))
// let postgresClient = try PostgresClient(configuration: postgres.worker, backgroundLogger: logger)
// let database = PostgresDatabase<PostgresCatalogWorkerScope>(client: postgresClient, logger: logger)
// let temporalWorker = try TemporalWorker(
//     configuration: .init(configReader: temporalConfig),
//     target: .dns(host: temporalHost, port: temporalConfig.int(forKey: "port", default: 7233)),
//     transportSecurity: try .mTLS(config: temporalTLSConfig, certificateReloader: temporalCertificateReloader),
//     activityContainers: ReservationActivities(service: activityService),
//     workflows: [ReservationWorkflow.self],
//     logger: logger
// )
// let serviceGroup = ServiceGroup(
//     services: [postgresClient, temporalCertificateReloader, temporalWorker],
//     gracefulShutdownSignals: [.sigint, .sigterm],
//     logger: logger
// )
SWIFT
cat > Sources/Catalog/Serve/Serve.swift <<'SWIFT'
// Serve composition root, abridged for the fixture: transports and configuration are omitted.
// One TemporalClient with its own temporal.tls reloader; both are in the ServiceGroup, and
// TemporalReservationWorkflowClient is injected into CreateReservationUseCase.
SWIFT
cat > Sources/Catalog/Database/Migrations.swift <<'SWIFT'
// The migration list is omitted from the abridged fixture.
SWIFT
git init -q && git add -A && git -c user.name=eval -c user.email=eval@example.com -c commit.gpgsign=false commit -qm "fixture"
