#!/bin/bash
set -euo pipefail
case_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cp "$case_dir/upstream-state.md" upstream-state.md
mkdir -p Sources/NotesCore/Notes Sources/NotesPostgres Sources/Notes/Serve Sources/Notes/Database Sources/Notes/JSON Tests/NotesCoreTests Upstream/AcmeAPIClient
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
    name: "acme-notes",
    platforms: [.macOS(.v15)],
    products: [.executable(name: "notes", targets: ["Notes"])],
    dependencies: [
        .package(url: "https://github.com/swift-microservices/swift-persistence.git", from: "0.2.0"),
        .package(url: "https://github.com/swift-microservices/swift-persistence-postgres.git", from: "0.2.1"),
        .package(url: "https://github.com/acme/acme-core.git", from: "0.1.0"),
        .package(url: "https://github.com/vapor/postgres-nio.git", from: "1.33.1"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.15.0"),
        .package(url: "https://github.com/apple/swift-openapi-runtime.git", from: "1.12.1", traits: []),
        .package(url: "https://github.com/acme/acme-api-client.git", from: "1.0.0"),
    ],
    targets: [
        .target(name: "NotesCore", dependencies: [
            .product(name: "Persistence", package: "swift-persistence"),
            .product(name: "AcmeAuthentication", package: "acme-core"),
            .product(name: "Logging", package: "swift-log"),
        ], swiftSettings: swiftSettings),
        .target(name: "NotesPostgres", dependencies: [
            "NotesCore",
            .product(name: "PersistencePostgres", package: "swift-persistence-postgres"),
            .product(name: "PostgresNIO", package: "postgres-nio"),
            .product(name: "Logging", package: "swift-log"),
        ], swiftSettings: swiftSettings),
        .executableTarget(name: "Notes", dependencies: [
            "NotesCore", "NotesPostgres",
            .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
            .product(name: "AcmeAPIClient", package: "acme-api-client"),
            .product(name: "Logging", package: "swift-log"),
        ], swiftSettings: swiftSettings),
        .testTarget(name: "NotesCoreTests", dependencies: [
            "NotesCore",
            .product(name: "AcmeAuthentication", package: "acme-core"),
            .product(name: "AcmeTesting", package: "acme-core"),
            .product(name: "Logging", package: "swift-log"),
        ], swiftSettings: swiftSettings),
    ],
    swiftLanguageModes: [.v6]
)
SWIFT
cat > Sources/NotesCore/Notes/Note.swift <<'SWIFT'
#if canImport(FoundationEssentials)
package import FoundationEssentials
#else
package import Foundation
#endif

package struct Note: Equatable, Sendable {
    package let id: UUID
    package let body: String
    package let creationDate: Date
}
SWIFT
cat > Sources/Notes/JSON/NoteJSONCodec.swift <<'SWIFT'
package import Foundation

package enum NoteJSONCodec {
    package static func decoder() -> JSONDecoder {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX"
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .formatted(formatter)
        return decoder
    }
}
SWIFT
cat > Sources/Notes/JSON/ClientIntegration.swift <<'SWIFT'
import AcmeAPIClient
import OpenAPIRuntime
// Provider API calls are omitted from the abridged fixture.
SWIFT
cat > Sources/NotesPostgres/DatabaseIntegration.swift <<'SWIFT'
package import Logging
package import NotesCore
package import PersistencePostgres
package import PostgresNIO
// Repository implementation is omitted from the abridged fixture.
SWIFT
cat > Sources/Notes/Serve/Serve.swift <<'SWIFT'
package import Logging
package import NotesCore
import NotesPostgres
// Composition root is omitted from the abridged fixture.
SWIFT
cat > Sources/Notes/Database/Migrations.swift <<'SWIFT'
// The migrations list is omitted from the abridged fixture.
SWIFT
cat > Upstream/AcmeAPIClient/Package.swift <<'SWIFT'
// swift-tools-version: 6.3
import PackageDescription

// Read-only evidence from a fictitious provider client for this scenario.
let package = Package(
    name: "acme-api-client",
    products: [.library(name: "AcmeAPIClient", targets: ["AcmeAPIClient"])],
    dependencies: [
        .package(url: "https://github.com/apple/swift-openapi-runtime.git", from: "1.12.1"),
    ],
    targets: [.target(name: "AcmeAPIClient", dependencies: [
        .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
    ])]
)
SWIFT
cat > foundation-linking.txt <<'TEXT'
Verified release executable dependency excerpt:
libFoundation.so
libFoundationInternationalization.so
lib_FoundationICU.so
libFoundationEssentials.so

The static Linux SDK CI job succeeds as well.
TEXT
