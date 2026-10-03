// swift-tools-version: 6.3
//
//  Package.swift
//  ExampleService
//
//  Created by Example Maintainer on 10/4/26.
//

import PackageDescription
let package = Package(
    name: "ExampleService",
    products: [.executable(name: "example-service", targets: ["ExampleService"])],
    dependencies: [.package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.8.2")],
    targets: [
        .target(name: "LibraryCore"),
        .executableTarget(name: "ExampleService", dependencies: ["LibraryCore", .product(name: "ArgumentParser", package: "swift-argument-parser")]),
        .testTarget(name: "LibraryCoreTests", dependencies: ["LibraryCore"])
    ],
    swiftLanguageModes: [.v6]
)
