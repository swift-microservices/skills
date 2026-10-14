#!/bin/bash
set -euo pipefail
root=acme-catalog
core=$root/Sources/CatalogCore/Items
mkdir -p "$core/Commands" "$core/UseCases/CreateItem" "$core/UseCases/GetItem" "$root/Sources/Catalog"

cat > "$root/Package.swift" <<'SWIFT'
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
        .package(url: "https://github.com/apple/swift-log.git", from: "1.15.0"),
        .package(url: "https://github.com/swift-microservices/swift-persistence.git", from: "0.2.0"),
        .package(url: "https://github.com/acme/acme-core.git", from: "0.1.0"),
    ],
    targets: [
        .target(
            name: "CatalogCore",
            dependencies: [
                .product(name: "Logging", package: "swift-log"),
                .product(name: "Persistence", package: "swift-persistence"),
                .product(name: "AcmeAuthentication", package: "acme-core"),
            ],
            swiftSettings: swiftSettings
        ),
        .executableTarget(
            name: "Catalog",
            dependencies: ["CatalogCore"],
            swiftSettings: swiftSettings
        ),
    ],
    swiftLanguageModes: [.v6]
)
SWIFT

cat > "$root/Sources/Catalog/Catalog.swift" <<'SWIFT'
@main
struct Catalog {
    static func main() async throws {}
}
SWIFT

cat > "$core/Item.swift" <<'SWIFT'
#if canImport(FoundationEssentials)
package import FoundationEssentials
#else
package import Foundation
#endif

package struct Item: Equatable, Sendable {
    package let id: UUID
    package let name: String
    package let creationDate: Date

    package init(id: UUID, name: String, creationDate: Date) {
        self.id = id
        self.name = name
        self.creationDate = creationDate
    }
}
SWIFT

cat > "$core/ItemRepository.swift" <<'SWIFT'
#if canImport(FoundationEssentials)
package import FoundationEssentials
#else
package import Foundation
#endif

package protocol ItemRepository: Sendable {
    /// Creates the item, or returns the existing one when the idempotency key was already used with the same name.
    /// Throws `ItemRepositoryError.idempotencyConflict` when the key was used with a different name.
    func create(_ command: CreateItemCommand) async throws -> Item
    func find(id: UUID) async throws -> Item?
}
SWIFT

cat > "$core/ItemRepositoryError.swift" <<'SWIFT'
package enum ItemRepositoryError: Error, Equatable {
    case duplicateName
    case idempotencyConflict
}
SWIFT

cat > "$core/Commands/CreateItemCommand.swift" <<'SWIFT'
package struct CreateItemCommand: Equatable, Sendable {
    package let idempotencyKey: String
    package let name: String

    package init(idempotencyKey: String, name: String) {
        self.idempotencyKey = idempotencyKey
        self.name = name
    }
}
SWIFT

cat > "$core/UseCases/CreateItem/CreateItemUseCaseInput.swift" <<'SWIFT'
package struct CreateItemUseCaseInput: Sendable {
    package let idempotencyKey: String
    package let name: String

    package init(idempotencyKey: String, name: String) {
        self.idempotencyKey = idempotencyKey
        self.name = name
    }
}
SWIFT

cat > "$core/UseCases/CreateItem/CreateItemUseCaseError.swift" <<'SWIFT'
package enum CreateItemUseCaseError: Error, Equatable {
    case forbidden
    case invalidName
    case invalidIdempotencyKey
    case duplicateName
    case idempotencyConflict
    case unknown
}
SWIFT

cat > "$core/UseCases/CreateItem/CreateItemUseCaseScope.swift" <<'SWIFT'
package protocol CreateItemUseCaseScope: Sendable {
    var itemRepository: any ItemRepository { get }
}
SWIFT

cat > "$core/UseCases/CreateItem/CreateItemUseCaseProtocol.swift" <<'SWIFT'
package import AcmeAuthentication

package protocol CreateItemUseCaseProtocol: Sendable {
    func callAsFunction(subject: UserIdentity, input: CreateItemUseCaseInput) async throws(CreateItemUseCaseError) -> Item
}
SWIFT

cat > "$core/UseCases/CreateItem/CreateItemUseCase.swift" <<'SWIFT'
package import AcmeAuthentication
package import Logging
package import Persistence

package struct CreateItemUseCase<DatabaseType: Database>: CreateItemUseCaseProtocol where DatabaseType.Scope: CreateItemUseCaseScope {
    private let database: DatabaseType
    private let logger: Logger

    package init(database: DatabaseType, logger: Logger) {
        self.database = database
        self.logger = logger
    }

    package func callAsFunction(
        subject: UserIdentity,
        input: CreateItemUseCaseInput
    ) async throws(CreateItemUseCaseError) -> Item {
        guard subject.role == .admin else {
            logger.warning("Item create refused: not an administrator", metadata: ["userId": "\(subject.userId)"])
            throw .forbidden
        }

        guard !input.name.isEmpty, input.name.count <= 200 else {
            throw .invalidName
        }

        guard !input.idempotencyKey.isEmpty, input.idempotencyKey.count <= 128 else {
            throw .invalidIdempotencyKey
        }

        do {
            let item = try await database.withTransaction { scope in
                let command = CreateItemCommand(idempotencyKey: input.idempotencyKey, name: input.name)
                return try await scope.itemRepository.create(command)
            }
            logger.info("Item created", metadata: ["itemId": "\(item.id)"])
            return item
        } catch ItemRepositoryError.duplicateName {
            logger.warning("Item create rejected: duplicate name", metadata: ["name": "\(input.name)"])
            throw .duplicateName
        } catch ItemRepositoryError.idempotencyConflict {
            logger.warning("Item create rejected: idempotency key reused with different input")
            throw .idempotencyConflict
        } catch {
            logger.error("Item create failed: unknown error", metadata: ["name": "\(input.name)", "error": "\(String(reflecting: error))"])
            throw .unknown
        }
    }
}
SWIFT

cat > "$core/UseCases/GetItem/GetItemUseCaseInput.swift" <<'SWIFT'
#if canImport(FoundationEssentials)
package import FoundationEssentials
#else
package import Foundation
#endif

package struct GetItemUseCaseInput: Sendable {
    package let id: UUID

    package init(id: UUID) {
        self.id = id
    }
}
SWIFT

cat > "$core/UseCases/GetItem/GetItemUseCaseError.swift" <<'SWIFT'
package enum GetItemUseCaseError: Error, Equatable {
    case itemNotFound
    case unknown
}
SWIFT

cat > "$core/UseCases/GetItem/GetItemUseCaseScope.swift" <<'SWIFT'
package protocol GetItemUseCaseScope: Sendable {
    var itemRepository: any ItemRepository { get }
}
SWIFT

cat > "$core/UseCases/GetItem/GetItemUseCaseProtocol.swift" <<'SWIFT'
package protocol GetItemUseCaseProtocol: Sendable {
    func callAsFunction(input: GetItemUseCaseInput) async throws(GetItemUseCaseError) -> Item
}
SWIFT

cat > "$core/UseCases/GetItem/GetItemUseCase.swift" <<'SWIFT'
package import Logging
package import Persistence

package struct GetItemUseCase<DatabaseType: Database>: GetItemUseCaseProtocol where DatabaseType.Scope: GetItemUseCaseScope {
    private let database: DatabaseType
    private let logger: Logger

    package init(database: DatabaseType, logger: Logger) {
        self.database = database
        self.logger = logger
    }

    package func callAsFunction(input: GetItemUseCaseInput) async throws(GetItemUseCaseError) -> Item {
        do {
            return try await database.withTransaction { scope in
                guard let item = try await scope.itemRepository.find(id: input.id) else {
                    throw GetItemUseCaseError.itemNotFound
                }
                return item
            }
        } catch let error as GetItemUseCaseError {
            if error == .itemNotFound {
                logger.warning("Item not found", metadata: ["itemId": "\(input.id)"])
            }
            throw error
        } catch {
            logger.error("Item read failed: unknown error", metadata: ["itemId": "\(input.id)", "error": "\(String(reflecting: error))"])
            throw .unknown
        }
    }
}
SWIFT
