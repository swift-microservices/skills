// swift-tools-version: 6.3
// Copyright (c) 2026 Zaid Rahhawi
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
    name: "swift-authentication",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .library(name: "Authentication", targets: ["Authentication"])
    ],
    dependencies: [
        .package(url: "https://github.com/swift-microservices/swift-operation-context.git", from: "0.1.0")
    ],
    targets: [
        .target(
            name: "Authentication",
            dependencies: [
                .product(name: "OperationContext", package: "swift-operation-context")
            ],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "AuthenticationTests",
            dependencies: [
                .target(name: "Authentication")
            ],
            swiftSettings: swiftSettings
        ),
    ],
    swiftLanguageModes: [.v6]
)
