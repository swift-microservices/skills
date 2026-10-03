// swift-tools-version: 6.3
import PackageDescription
let package = Package(
    name: "DatabaseCore",
    platforms: [.macOS(.v15)],
    products: [.library(name: "DatabaseCore", targets: ["DatabaseCore"])],
    dependencies: [
        .package(url: "https://github.com/swift-microservices/swift-persistence-postgres.git", from: "0.2.0"),
        .package(url: "https://github.com/vapor/postgres-nio.git", from: "1.23.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.6.0")
    ],
    targets: [
        .target(name: "DatabaseCore", dependencies: [.product(name: "PersistencePostgres", package: "swift-persistence-postgres"), .product(name: "PostgresNIO", package: "postgres-nio"), .product(name: "Logging", package: "swift-log")]),
        .testTarget(name: "DatabaseCoreTests", dependencies: ["DatabaseCore"])
    ],
    swiftLanguageModes: [.v6]
)
