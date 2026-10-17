// swift-tools-version: 6.3
// Copyright (c) 2026 Example Maintainers
// SPDX-License-Identifier: MIT
// See LICENSE for license information.

import PackageDescription

let package = Package(
    name: "swift-order-store",
    platforms: [.macOS(.v15)],
    products: [.library(name: "OrderStore", targets: ["OrderStore"])],
    dependencies: [.package(url: "https://github.com/vapor/postgres-nio.git", from: "1.33.0")],
    targets: [
        .target(name: "OrderStore", dependencies: [.product(name: "PostgresNIO", package: "postgres-nio")]),
        .testTarget(name: "OrderStoreTests", dependencies: ["OrderStore"]),
    ],
    swiftLanguageModes: [.v6]
)
