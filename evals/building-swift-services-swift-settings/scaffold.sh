#!/bin/bash
set -euo pipefail
mkdir -p Sources/UtilityCore Sources/UtilityAdapter Sources/UtilityExtensions Sources/UtilityApp Tests/UtilityTests
cat > Package.swift <<'SWIFT'
// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "Utility",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "UtilityAdapter", targets: ["UtilityAdapter"]),
        .executable(name: "utility", targets: ["UtilityApp"]),
    ],
    targets: [
        .target(name: "UtilityCore"),
        .target(name: "UtilityAdapter", dependencies: ["UtilityCore"]),
        .target(name: "UtilityExtensions"),
        .executableTarget(name: "UtilityApp", dependencies: ["UtilityAdapter", "UtilityCore", "UtilityExtensions"]),
        .testTarget(name: "UtilityTests", dependencies: ["UtilityAdapter", "UtilityCore"]),
    ],
    swiftLanguageModes: [.v6]
)
SWIFT
cat > Sources/UtilityCore/Record.swift <<'SWIFT'
public struct Record: Sendable, Equatable {
    public let value: Int
    public init(value: Int) { self.value = value }
}

public protocol OperationRunner: Sendable {
    func run<T: Sendable>(_ operation: @Sendable () async throws -> T) async rethrows -> T
}
SWIFT
cat > Sources/UtilityAdapter/InlineRunner.swift <<'SWIFT'
import UtilityCore

public struct InlineRunner: OperationRunner {
    public init() {}
    public func run<T: Sendable>(_ operation: @Sendable () async throws -> T) async rethrows -> T {
        try await operation()
    }
    public func record(value: Int) -> Record { Record(value: value) }
}

package func packageRecord(value: Int) -> Record { Record(value: value) }
SWIFT
cat > Sources/UtilityExtensions/String+Label.swift <<'SWIFT'
extension String {
    public var utilityLabel: String { "utility: \(self)" }
}
SWIFT
cat > Sources/UtilityApp/Imports.swift <<'SWIFT'
import UtilityExtensions
SWIFT
cat > Sources/UtilityApp/main.swift <<'SWIFT'
import UtilityAdapter
import UtilityCore

let runner: OperationRunner = InlineRunner()
let value = await runner.run { 42 }
print(String(value).utilityLabel)
SWIFT
cat > Tests/UtilityTests/UtilityTests.swift <<'SWIFT'
import Testing
import UtilityAdapter

@Test func records() {
    #expect(InlineRunner().record(value: 42).value == 42)
}
SWIFT
