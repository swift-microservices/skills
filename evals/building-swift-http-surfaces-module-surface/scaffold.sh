#!/bin/bash
# Lays down an abridged gRPC-only modular monolith whose catalog module is getting an HTTP surface.
set -euo pipefail
mkdir -p Sources/Acme/Serve Sources/AcmeAuthentication Sources/AcmePersistence \
    Sources/CatalogCore/Items/UseCases Sources/CatalogCore/Favorites/UseCases \
    Sources/CatalogPostgres/Migrations/Favorite Sources/CatalogGRPC
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
    name: "acme-backend",
    platforms: [.macOS(.v15)],
    products: [.executable(name: "acme", targets: ["Acme"])],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.6.0"),
        .package(url: "https://github.com/apple/swift-configuration.git", from: "1.2.0", traits: []),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.6.0"),
        .package(url: "https://github.com/swift-server/swift-service-lifecycle.git", from: "2.8.0"),
        .package(url: "https://github.com/grpc/grpc-swift-2.git", from: "2.4.0"),
        .package(url: "https://github.com/swift-microservices/swift-operation-context.git", from: "0.1.0"),
        .package(url: "https://github.com/swift-microservices/swift-persistence.git", from: "0.2.0"),
        .package(url: "https://github.com/swift-microservices/swift-persistence-postgres.git", from: "0.3.0"),
        .package(url: "https://github.com/swift-microservices/swift-authentication.git", from: "0.4.0"),
        .package(url: "https://github.com/swift-microservices/swift-authentication-jwt.git", from: "0.4.0"),
        .package(url: "https://github.com/swift-microservices/swift-authentication-grpc.git", from: "0.4.0"),
    ],
    targets: [
        .target(
            name: "AcmeAuthentication",
            dependencies: [
                .product(name: "Authentication", package: "swift-authentication"),
                .product(name: "AuthenticationJWT", package: "swift-authentication-jwt"),
                .product(name: "OperationContext", package: "swift-operation-context"),
            ],
            swiftSettings: swiftSettings
        ),
        .target(
            name: "AcmePersistence",
            dependencies: [
                "AcmeAuthentication",
                .product(name: "GRPCCore", package: "grpc-swift-2"),
                .product(name: "OperationContext", package: "swift-operation-context"),
                .product(name: "PersistencePostgres", package: "swift-persistence-postgres"),
            ],
            swiftSettings: swiftSettings
        ),
        .target(
            name: "CatalogCore",
            dependencies: [
                "AcmeAuthentication",
                .product(name: "Logging", package: "swift-log"),
                .product(name: "Persistence", package: "swift-persistence"),
            ],
            swiftSettings: swiftSettings
        ),
        .target(
            name: "CatalogPostgres",
            dependencies: [
                "CatalogCore",
                .product(name: "PersistencePostgres", package: "swift-persistence-postgres"),
            ],
            swiftSettings: swiftSettings
        ),
        .target(
            name: "CatalogGRPC",
            dependencies: [
                "CatalogCore",
                "AcmeAuthentication",
                .product(name: "GRPCCore", package: "grpc-swift-2"),
            ],
            swiftSettings: swiftSettings
        ),
        .executableTarget(
            name: "Acme",
            dependencies: [
                "AcmeAuthentication",
                "AcmePersistence",
                "CatalogCore",
                "CatalogPostgres",
                "CatalogGRPC",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "Configuration", package: "swift-configuration"),
                .product(name: "Logging", package: "swift-log"),
                .product(name: "ServiceLifecycle", package: "swift-service-lifecycle"),
                .product(name: "AuthenticationJWT", package: "swift-authentication-jwt"),
                .product(name: "AuthenticationGRPC", package: "swift-authentication-grpc"),
                .product(name: "GRPCCore", package: "grpc-swift-2"),
            ],
            swiftSettings: swiftSettings
        ),
    ],
    swiftLanguageModes: [.v6]
)
SWIFT
cat > Sources/AcmeAuthentication/UserIdentity.swift <<'SWIFT'
#if canImport(FoundationEssentials)
package import FoundationEssentials
#else
package import Foundation
#endif

/// The verified user a token proves. Abridged: the JWT claims and payload conformance are omitted.
package struct UserIdentity: Equatable, Sendable {
    package let userId: UUID
    package let role: UserRole

    package init(userId: UUID, role: UserRole) {
        self.userId = userId
        self.role = role
    }
}

package enum UserRole: String, Sendable {
    case user
    case admin
}
SWIFT
cat > Sources/AcmeAuthentication/OperationContext+User.swift <<'SWIFT'
package import Authentication
package import OperationContext

extension OperationContext {
    /// The verified user the bearer interceptor or middleware bound, if any.
    package var user: Principal<UserIdentity, String>? {
        get { self[PrincipalKey<UserIdentity, String>.self] }
        set { self[PrincipalKey<UserIdentity, String>.self] = newValue }
    }
}
SWIFT
cat > Sources/AcmePersistence/PostgresSettings+User.swift <<'SWIFT'
package import AcmeAuthentication
package import PersistencePostgres

extension PostgresSettings {
    /// The one setting the tenant policies read, `app.caller_user_id`, lowercased.
    package static func user(_ user: UserIdentity) -> PostgresSettings {
        ["app.caller_user_id": user.userId.uuidString.lowercased()]
    }
}
SWIFT
cat > Sources/AcmePersistence/UserSettingsInterceptor.swift <<'SWIFT'
// Abridged: the gRPC binding that turns the bound user into the tenant setting of every
// transaction in the call. Applied after BearerAuthenticationInterceptor on CatalogService.
SWIFT
cat > Sources/CatalogCore/Items/Item.swift <<'SWIFT'
#if canImport(FoundationEssentials)
package import FoundationEssentials
#else
package import Foundation
#endif

package struct Item: Equatable, Sendable {
    package let id: UUID
    package let name: String

    package init(id: UUID, name: String) {
        self.id = id
        self.name = name
    }
}
SWIFT
cat > Sources/CatalogCore/Items/UseCases/ListItemsUseCase.swift <<'SWIFT'
/// Anyone may list the catalogue.
package protocol ListItemsUseCaseProtocol: Sendable {
    func callAsFunction() async throws(ListItemsUseCaseError) -> [Item]
}

package enum ListItemsUseCaseError: Error, Equatable {
    case unknown
}
SWIFT
cat > Sources/CatalogCore/Items/UseCases/GetItemUseCase.swift <<'SWIFT'
#if canImport(FoundationEssentials)
package import FoundationEssentials
#else
package import Foundation
#endif

/// Anyone may read one item.
package protocol GetItemUseCaseProtocol: Sendable {
    func callAsFunction(input: GetItemUseCaseInput) async throws(GetItemUseCaseError) -> Item
}

package struct GetItemUseCaseInput: Sendable {
    package let id: UUID

    package init(id: UUID) {
        self.id = id
    }
}

package enum GetItemUseCaseError: Error, Equatable {
    case notFound
    case unknown
}
SWIFT
cat > Sources/CatalogCore/Items/UseCases/CreateItemUseCase.swift <<'SWIFT'
/// Administrators add items; the use case refuses anyone else with `.forbidden`.
package protocol CreateItemUseCaseProtocol: Sendable {
    func callAsFunction(subject: UserIdentity, input: CreateItemUseCaseInput) async throws(CreateItemUseCaseError) -> Item
}

package struct CreateItemUseCaseInput: Sendable {
    package let name: String

    package init(name: String) {
        self.name = name
    }
}

package enum CreateItemUseCaseError: Error, Equatable {
    case invalidName
    case forbidden
    case duplicateName
    case unknown
}
SWIFT
cat > Sources/CatalogCore/Favorites/UseCases/ListFavoritesUseCase.swift <<'SWIFT'
/// The caller's own favourite items, read under the favorites tenant policy.
package protocol ListFavoritesUseCaseProtocol: Sendable {
    func callAsFunction(subject: UserIdentity) async throws(ListFavoritesUseCaseError) -> [Item]
}

package enum ListFavoritesUseCaseError: Error, Equatable {
    case unknown
}
SWIFT
cat > Sources/CatalogCore/Favorites/UseCases/AddFavoriteUseCase.swift <<'SWIFT'
#if canImport(FoundationEssentials)
package import FoundationEssentials
#else
package import Foundation
#endif

/// Adds an item to the caller's own favourites.
package protocol AddFavoriteUseCaseProtocol: Sendable {
    func callAsFunction(subject: UserIdentity, input: AddFavoriteUseCaseInput) async throws(AddFavoriteUseCaseError) -> Item
}

package struct AddFavoriteUseCaseInput: Sendable {
    package let itemId: UUID

    package init(itemId: UUID) {
        self.itemId = itemId
    }
}

package enum AddFavoriteUseCaseError: Error, Equatable {
    case itemNotFound
    case alreadyFavorite
    case unknown
}
SWIFT
cat > Sources/CatalogPostgres/Migrations/Favorite/CreateFavoritesRLSPolicy.swift <<'SWIFT'
// Abridged: favorites rows are visible only where user_id = current_setting('app.caller_user_id')::uuid.
SWIFT
cat > Sources/CatalogGRPC/ItemService.swift <<'SWIFT'
// Abridged: the gRPC conformance over the same use cases.
SWIFT
cat > Sources/Acme/Serve/Serve.swift <<'SWIFT'
import AcmeAuthentication
import AcmePersistence
import ArgumentParser
import AuthenticationGRPC
import AuthenticationJWT
import CatalogCore
import CatalogGRPC
import CatalogPostgres
import Configuration
import GRPCCore
import Logging
import ServiceLifecycle

struct Serve: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "serve", abstract: "Serve gRPC")

    func run() async throws {
        // MARK: - Configuration
        let config = ConfigReader(providers: [EnvironmentVariablesProvider(), InMemoryProvider.applicationDefaults])

        // MARK: - Logging
        // Abridged: bootstraps logging once.
        let logger = Logger(label: "acme")

        // MARK: - Infrastructure
        // Abridged: the Postgres clients, the token key, and the certificate reloader.
        let userAuthenticator: JWTAuthenticator<UserIdentity> = try await makeUserAuthenticator(config: config.scoped(to: "jwt"))
        let catalogDatabase = try makeCatalogDatabase(config: config.scoped(to: "postgres"), logger: logger)

        // MARK: - Composition
        let listItemsUseCase = ListItemsUseCase(database: catalogDatabase, logger: logger)
        let getItemUseCase = GetItemUseCase(database: catalogDatabase, logger: logger)
        let createItemUseCase = CreateItemUseCase(database: catalogDatabase, logger: logger)
        let listFavoritesUseCase = ListFavoritesUseCase(database: catalogDatabase, logger: logger)
        let addFavoriteUseCase = AddFavoriteUseCase(database: catalogDatabase, logger: logger)
        let itemService = ItemService(
            listItemsUseCase: listItemsUseCase,
            getItemUseCase: getItemUseCase,
            createItemUseCase: createItemUseCase
        )

        // MARK: - gRPC
        let server = try makeGRPCServer(
            config: config.scoped(to: "grpc.server"),
            services: [itemService],
            userAuthenticator: userAuthenticator
        )

        // MARK: - Lifecycle
        let serviceGroup = ServiceGroup(
            services: [server],
            gracefulShutdownSignals: [.sigint, .sigterm],
            logger: logger
        )
        try await serviceGroup.run()
    }
}
SWIFT
