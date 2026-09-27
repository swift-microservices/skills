#!/bin/bash
set -euo pipefail
case_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cp "$case_dir/upstream-state.md" upstream-state.md
mkdir -p Sources/EventsCore Sources/EventsHTTP Sources/Events Tests/EventsHTTPTests
cat > Package.swift <<'SWIFT'
// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "acme-events",
    platforms: [.macOS(.v15)],
    products: [.executable(name: "events", targets: ["Events"])],
    dependencies: [
        .package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "2.26.0"),
        .package(url: "https://github.com/hummingbird-project/hummingbird-auth.git", from: "2.2.0"),
        .package(url: "https://github.com/apple/swift-openapi-runtime.git", from: "1.12.0"),
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.98.0"),
    ],
    targets: [
        .target(name: "EventsCore"),
        .target(name: "EventsHTTP", dependencies: [
            "EventsCore",
            .product(name: "Hummingbird", package: "hummingbird"),
            .product(name: "HummingbirdAuth", package: "hummingbird-auth"),
            .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
            .product(name: "NIOCore", package: "swift-nio"),
            .product(name: "NIOFoundationCompat", package: "swift-nio"),
        ]),
        .executableTarget(name: "Events", dependencies: ["EventsHTTP"]),
        .testTarget(name: "EventsHTTPTests", dependencies: [
            "EventsHTTP",
            .product(name: "NIOCore", package: "swift-nio"),
        ]),
    ],
    swiftLanguageModes: [.v6]
)
SWIFT
cat > Sources/EventsHTTP/EventJSONCodec.swift <<'SWIFT'
import Foundation
import NIOCore
import NIOFoundationCompat

package struct EventPayload: Codable, Sendable {
    package let creationDate: Date
}

package enum EventJSONCodec {
    package static func decode(_ buffer: ByteBuffer) throws -> EventPayload {
        let decoder = JSONDecoder()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX"
        decoder.dateDecodingStrategy = .formatted(formatter)
        guard let payload = try buffer.getJSONDecodable(
            EventPayload.self,
            at: buffer.readerIndex,
            length: buffer.readableBytes,
            decoder: decoder
        ) else {
            throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Missing event JSON"))
        }
        return payload
    }
}
SWIFT
cat > Sources/EventsHTTP/ConfigurationIntegration.swift <<'SWIFT'
import Hummingbird

// Existing composition code uses ApplicationConfiguration(reader:).
// ConfigurationSupport must remain enabled when the manifest is updated.
SWIFT
cat > Sources/EventsCore/EventsCore.swift <<'SWIFT'
// Domain use cases are outside this fixture's requested change.
SWIFT
cat > Sources/Events/main.swift <<'SWIFT'
import EventsHTTP
// The running application is outside this fixture's requested change.
SWIFT
