#!/bin/bash
# Lays down an abridged catalog service that is about to notify a partner over a webhook.
set -euo pipefail
mkdir -p Sources/CatalogCore/Items Sources/CatalogWebhooks Sources/Catalog
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
        .package(url: "https://github.com/apple/swift-log.git", from: "1.6.0"),
    ],
    targets: [
        .target(name: "CatalogCore", swiftSettings: swiftSettings),
        .target(
            name: "CatalogWebhooks",
            dependencies: [
                "CatalogCore",
                .product(name: "Logging", package: "swift-log"),
            ],
            swiftSettings: swiftSettings
        ),
        .executableTarget(
            name: "Catalog",
            dependencies: [
                "CatalogCore",
                "CatalogWebhooks",
                .product(name: "Logging", package: "swift-log"),
            ],
            swiftSettings: swiftSettings
        ),
    ],
    swiftLanguageModes: [.v6]
)
SWIFT
cat > Sources/CatalogCore/Items/Item.swift <<'SWIFT'
#if canImport(FoundationEssentials)
package import FoundationEssentials
#else
package import Foundation
#endif

/// A catalogue item.
package struct Item: Equatable, Sendable {
    package let id: UUID
    package let name: String
    package let priceCents: Int

    package init(id: UUID, name: String, priceCents: Int) {
        self.id = id
        self.name = name
        self.priceCents = priceCents
    }
}
SWIFT
cat > Sources/CatalogWebhooks/WebhookTransport.swift <<'SWIFT'
/// Sends one HTTP POST and returns the response status code.
///
/// The production conformance wraps the service's HTTP client; it throws only when no response
/// arrived (connection refused, timeout).
package protocol WebhookTransport: Sendable {
    func post(body: [UInt8], to url: String, headers: [String: String]) async throws -> Int
}
SWIFT
cat > Sources/Catalog/main.swift <<'SWIFT'
// Abridged: the composition root bootstraps logging, builds the transport and the use cases,
// and runs the service group.
SWIFT
