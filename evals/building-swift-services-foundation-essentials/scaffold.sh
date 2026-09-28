#!/bin/bash
set -euo pipefail
case_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cp "$case_dir/upstream-state.md" upstream-state.md
mkdir -p Sources/EventsCore Sources/EventsHTTP Sources/Events Tests/EventsHTTPTests
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
    name: "acme-events",
    platforms: [.macOS(.v15)],
    products: [.executable(name: "events", targets: ["Events"])],
    dependencies: [
    ],
    targets: [
        .target(name: "EventsCore", swiftSettings: swiftSettings),
        .target(name: "EventsHTTP", dependencies: [
            "EventsCore",
        ], swiftSettings: swiftSettings),
        .executableTarget(name: "Events", dependencies: [
            "EventsHTTP",
        ], swiftSettings: swiftSettings),
        .testTarget(name: "EventsHTTPTests", dependencies: [
            "EventsHTTP",
        ], swiftSettings: swiftSettings),
    ],
    swiftLanguageModes: [.v6]
)
SWIFT
cat > Sources/EventsHTTP/EventPayload.swift <<'SWIFT'
#if canImport(FoundationEssentials)
package import FoundationEssentials
#else
package import Foundation
#endif

package struct EventPayload: Decodable, Sendable {
    package let creationDate: Date
}
SWIFT
cat > Sources/EventsCore/EventsCore.swift <<'SWIFT'
// Domain use cases are outside this fixture's requested change.
SWIFT
cat > Sources/Events/main.swift <<'SWIFT'
// The composition root reads its configuration from environment variables and builds the
// Hummingbird application through Hummingbird's swift-configuration integration.
SWIFT
