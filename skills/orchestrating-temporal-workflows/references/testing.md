# Testing workflows

A Workflow is tested by running it: the real Workflows and Activity containers on the SDK's time-skipping test server, registered exactly as `worker run` registers them, over mock Activity-service protocols. That run is also the payload check, because every value goes through the real converter; no hand-kept list of round trips is needed.

## Contents

- [The test target](#the-test-target)
- [One server for every suite](#one-server-for-every-suite)
- [Running a Workflow](#running-a-workflow)
- [Covering every branch](#covering-every-branch)
- [Activity names are unique](#activity-names-are-unique)
- [Recording and replaying histories](#recording-and-replaying-histories)
- [Running the tests](#running-the-tests)

## The test target

`<Service>WorkflowsTests` sits beside `<Service>CoreTests`, on swift-testing, with the shared [Swift settings](../../writing-swift-server-code/references/swift-settings.md). The recorded histories are JSON fixtures, not sources, so the target excludes their directory:

```swift
.testTarget(
    name: "CatalogWorkflowsTests",
    dependencies: [
        "CatalogCore",
        "CatalogWorkflows",
        .product(name: "Logging", package: "swift-log"),
        .product(name: "Temporal", package: "swift-temporal-sdk"),
        .product(name: "TemporalTestKit", package: "swift-temporal-sdk"),
    ],
    exclude: ["Histories"],
    swiftSettings: swiftSettings
),
```

```text
Tests/<Service>WorkflowsTests/
  <Service>WorkflowTests.swift              # the parent suite that owns the server
  <Feature>WorkflowTests.swift              # one nested suite per Workflow
  <Feature>WorkflowReplayTests.swift
  <Service>WorkerRegistrationTests.swift
  Mocks/
  Support/<Service>Worker.swift
  Support/WorkflowHistories.swift
  Histories/<feature>-<outcome>.json
```

## One server for every suite

Time skipping belongs to the server, not the test: a test waiting on its result advances time for every Workflow on that server. One parent suite carries the trait, and every Workflow suite nests under it in an extension, so one server serves them all and `.serialized` orders them:

```swift
import TemporalTestKit
import Testing

/// One time-skipping server for every Workflow suite.
@Suite("Catalog workflows", .temporalTimeSkippingTestServer, .serialized)
struct CatalogWorkflowTests {}
```

## Running a Workflow

One helper builds the Activity list `worker run` builds, and one runs a worker registered the same way:

```swift
import CatalogCore
import CatalogWorkflows
import Logging
import Temporal
import TemporalTestKit
import Testing

/// The Activities `worker run` registers, every container, over the given mocks.
func makeCatalogActivities(service: MockReservationActivityService) -> [any ActivityDefinition] {
    ReservationActivities(service: service).allActivities
}

/// A worker registered the way `worker run` registers it, on a fresh task queue.
func withCatalogWorker(
    service: MockReservationActivityService,
    body: sending @escaping (String, TemporalClient) async throws -> Void
) async throws {
    let testServer = try #require(TemporalTestServer.timeSkippingTestServer)
    var logger = Logger(label: "CatalogWorkflowTests")
    logger.logLevel = .warning
    try await testServer.withWorkerAndClient(
        activities: makeCatalogActivities(service: service),
        workflows: [ReservationWorkflow.self],
        logger: logger,
        body: body
    )
}
```

Each Workflow suite is an extension of the parent, `.serialized` with a time limit:

```swift
import CatalogCore
import CatalogWorkflows
import Temporal
import TemporalTestKit
import Testing

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

extension CatalogWorkflowTests {
    @Suite("Reservation workflow", .serialized, .timeLimit(.minutes(1)))
    struct ReservationWorkflowTests {
        @Test("an unconfirmed reservation is released when it expires")
        func unconfirmedReservationExpires() async throws {
            let service = MockReservationActivityService()

            try await withCatalogWorker(service: service) { taskQueue, client in
                let handle = try await client.startWorkflow(
                    type: ReservationWorkflow.self,
                    options: WorkflowOptions(id: "catalog-reservation-\(UUID())", taskQueue: taskQueue),
                    input: ReservationWorkflow.Input(reservationId: UUID())
                )
                let result = try await handle.result()
                #expect(result.state == .expired)
                try await WorkflowHistories.record(handle, as: "reservation-expired")
            }

            let calls = await service.calls
            #expect(calls == [.reserve, .release])
        }

        @Test("a reservation that cannot be held fails without retrying")
        func invalidReservationFails() async throws {
            let service = MockReservationActivityService(reserveError: .invalidState)

            try await withCatalogWorker(service: service) { taskQueue, client in
                let handle = try await client.startWorkflow(
                    type: ReservationWorkflow.self,
                    options: WorkflowOptions(id: "catalog-reservation-\(UUID())", taskQueue: taskQueue),
                    input: ReservationWorkflow.Input(reservationId: UUID())
                )
                await #expect(throws: (any Error).self) {
                    try await handle.result()
                }
            }

            let calls = await service.calls
            #expect(calls == [.reserve])
        }
    }
}
```

- `handle.result()` lets the server skip time while it waits, so a day-long timer fires in milliseconds. Nothing advances time until something waits, so send a signal (`handle.signal(signalType: ReservationWorkflow.Confirm.self)`) before awaiting the result, and query (`handle.query(queryType: ReservationWorkflow.CurrentState.self)`) before the signal to observe `.inProgress`.
- The mock is an actor recording each call; read its calls into a local before `#expect`, so a failure prints them.

## Covering every branch

Cover each outcome a signal, a query, or a timer decides; each case of an Activity output the Workflow switches on; a child Workflow started from its parent; and one failure an Activity marks non-retryable, asserting the Activity ran once.

An Activity that keeps failing, because a payload cannot convert or an error is mapped as retryable, never produces a result: the test fails with `Unexpected empty workflow history` when `result()` gives up its long poll, or on the suite's time limit. Read that as "an Activity never completed" and look in the worker log for the failure it retried.

## Activity names are unique

Every container on a worker shares one Activity-name space, and a name defaults to the method name. A name two containers share silently runs one container's Activity for the other's Workflow; on the test server that is a Workflow that never finishes and a suite that hangs past its time limit, not a failure that names the Activity. Wherever a worker registers more than one container, check the list `worker run` builds before anything runs. The check needs no server, so it sits outside the parent suite:

```swift
import Temporal
import Testing

@Suite("Catalog worker registration")
struct CatalogWorkerRegistrationTests {
    @Test("every activity the worker registers has a name of its own")
    func activityNamesAreUnique() {
        let names = makeCatalogActivities(service: MockReservationActivityService()).map { type(of: $0).name }
        let duplicates = Dictionary(grouping: names, by: { $0 }).filter { $0.value.count > 1 }.keys.sorted()
        #expect(duplicates.isEmpty, "Registered more than once: \(duplicates)")
    }
}
```

A failure is fixed with `@Activity(name:)` on one of the two methods, as [activities.md](activities.md#activities) describes. The worker log's `Duplicate activity registration` is the same symptom in a running process.

## Recording and replaying histories

A Workflow still running when a release deploys replays its recorded history against the new code. Record each end-to-end run's history as a fixture and replay every fixture with `WorkflowReplayer`:

```swift
import Temporal

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

enum WorkflowHistories {
    private static let directory = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("Histories")

    static func record<Workflow: WorkflowDefinition>(_ handle: WorkflowHandle<Workflow>, as name: String) async throws {
        guard ProcessInfo.processInfo.environment["RECORD_WORKFLOW_HISTORIES"] != nil else {
            return
        }
        let history = try await handle.fetchHistory()
        try history.toJSON().write(to: directory.appendingPathComponent("\(name).json"))
    }

    static func load(_ name: String) throws -> WorkflowHistory {
        let data = try Data(contentsOf: directory.appendingPathComponent("\(name).json"))
        return try WorkflowHistory.fromJSON(workflowID: name, jsonData: data)
    }
}
```

```swift
import CatalogWorkflows
import Temporal
import Testing

@Suite("Reservation workflow replay")
struct ReservationWorkflowReplayTests {
    @Test("a recorded history replays deterministically", arguments: ["reservation-confirmed", "reservation-expired"])
    func recordedHistoryReplays(name: String) async throws {
        let replayer = WorkflowReplayer(configuration: .init(workflows: [ReservationWorkflow.self]))
        let result = try await replayer.replayWorkflow(history: try WorkflowHistories.load(name), throwOnReplayFailure: false)
        #expect(result.replayFailure == nil)
    }
}
```

Record with `RECORD_WORKFLOW_HISTORIES=1 swift test --filter <Service>WorkflowsTests` and commit the fixtures. A fixture holds every payload, so tests use mock data only, never a real name, address, or token. Re-record only for a change meant to break running Workflows, shipped as [workflows.md](workflows.md#payloads) describes; any other failing replay is the change breaking them.

## Running the tests

Run `swift test` locally before pushing, and in CI where it runs. The first run downloads the test server, so a machine or runner needs the network once.
