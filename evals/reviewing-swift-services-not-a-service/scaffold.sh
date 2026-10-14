#!/bin/bash
# Lays down a small reusable library package (no executable, no Core/Postgres/transport targets).
set -euo pipefail
mkdir -p Sources/RetryBudget Tests/RetryBudgetTests
cat > Package.swift <<'SWIFT'
// swift-tools-version: 6.3
// Copyright (c) 2026 Example Authors
// SPDX-License-Identifier: MIT
// See LICENSE for license information.

import PackageDescription

let swiftSettings: [SwiftSetting] = [
    .enableUpcomingFeature("ExistentialAny"),
    .enableUpcomingFeature("MemberImportVisibility"),
    .enableUpcomingFeature("InternalImportsByDefault"),
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
]

let package = Package(
    name: "swift-retry-budget",
    platforms: [.macOS(.v15)],
    products: [.library(name: "RetryBudget", targets: ["RetryBudget"])],
    dependencies: [
        .package(url: "https://github.com/apple/swift-log.git", from: "1.6.0"),
    ],
    targets: [
        .target(
            name: "RetryBudget",
            dependencies: [.product(name: "Logging", package: "swift-log")],
            swiftSettings: swiftSettings
        ),
        .testTarget(name: "RetryBudgetTests", dependencies: ["RetryBudget"], swiftSettings: swiftSettings),
    ],
    swiftLanguageModes: [.v6]
)
SWIFT
cat > Sources/RetryBudget/RetryBudget.swift <<'SWIFT'
// Copyright (c) 2026 Example Authors
// SPDX-License-Identifier: MIT
// See LICENSE for license information.

/// A token bucket that limits how many retries a client may spend relative to its successful calls.
public struct RetryBudget: Sendable {
    /// The most retry tokens the budget holds.
    public let capacity: Int
    /// The tokens currently available.
    public private(set) var tokens: Int

    /// Creates a full budget.
    public init(capacity: Int) {
        precondition(capacity > 0, "A retry budget needs a positive capacity.")
        self.capacity = capacity
        self.tokens = capacity
    }

    /// Spends one token for a retry, returning whether the retry may proceed.
    public mutating func spend() -> Bool {
        guard tokens > 0 else { return false }
        tokens -= 1
        return true
    }

    /// Returns one token after a successful call, up to the capacity.
    public mutating func refill() {
        tokens = min(capacity, tokens + 1)
    }
}
SWIFT
cat > Tests/RetryBudgetTests/RetryBudgetTests.swift <<'SWIFT'
// Copyright (c) 2026 Example Authors
// SPDX-License-Identifier: MIT
// See LICENSE for license information.

import RetryBudget
import Testing

@Suite("Retry budget")
struct RetryBudgetTests {
    @Test("an exhausted budget refuses retries until a success refills it")
    func exhaustedBudgetRefuses() {
        var budget = RetryBudget(capacity: 1)
        #expect(budget.spend())
        #expect(!budget.spend())
        budget.refill()
        #expect(budget.spend())
    }
}
SWIFT
cat > LICENSE <<'TEXT'
MIT License

Copyright (c) 2026 Example Authors
TEXT
printf '.build/\nPackage.resolved\n' > .gitignore
git init -q && git add -A && git -c user.name=eval -c user.email=eval@example.com -c commit.gpgsign=false commit -qm "fixture"
