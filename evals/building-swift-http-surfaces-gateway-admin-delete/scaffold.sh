#!/bin/bash
set -euo pipefail
mkdir -p acme-api/Sources/API/Contexts acme-api/Sources/API/Controllers acme-api/Sources/Acme/Serve
cat > acme-api/Package.swift <<'SWIFT'
// swift-tools-version: 6.3
import PackageDescription

let swiftSettings: [SwiftSetting] = [
    .enableUpcomingFeature("ExistentialAny"),
    .enableUpcomingFeature("MemberImportVisibility"),
    .enableUpcomingFeature("InternalImportsByDefault"),
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
]

let package = Package(
    name: "acme-api",
    platforms: [.macOS(.v15)],
    products: [.executable(name: "acme", targets: ["Acme"])],
    dependencies: [
        .package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "2.27.0", traits: ["ConfigurationSupport"]),
        .package(url: "https://github.com/hummingbird-project/hummingbird-auth.git", from: "2.5.0"),
        .package(url: "https://github.com/grpc/grpc-swift-2.git", from: "2.4.0"),
        .package(url: "https://github.com/swift-microservices/swift-authentication.git", from: "0.3.0"),
        .package(url: "https://github.com/swift-microservices/swift-authentication-hummingbird.git", from: "0.3.0"),
        .package(url: "https://github.com/acme/acme-core.git", from: "0.1.0"),
        .package(url: "https://github.com/acme/acme-protos.git", from: "0.1.0"),
    ],
    targets: [
        .target(
            name: "API",
            dependencies: [
                .product(name: "Hummingbird", package: "hummingbird"),
                .product(name: "HummingbirdAuth", package: "hummingbird-auth"),
                .product(name: "Authentication", package: "swift-authentication"),
                .product(name: "AuthenticationHummingbird", package: "swift-authentication-hummingbird"),
                .product(name: "GRPCCore", package: "grpc-swift-2"),
                .product(name: "AcmeAuthentication", package: "acme-core"),
                .product(name: "CatalogProtos", package: "acme-protos"),
            ],
            swiftSettings: swiftSettings
        ),
        .executableTarget(
            name: "Acme",
            dependencies: [
                "API",
                .product(name: "AuthenticationHummingbird", package: "swift-authentication-hummingbird"),
            ],
            swiftSettings: swiftSettings
        ),
    ],
    swiftLanguageModes: [.v6]
)
SWIFT
cat > acme-api/Sources/API/Contexts/IdentityRequestContext.swift <<'SWIFT'
package import AcmeAuthentication
package import Hummingbird
package import HummingbirdAuth

package struct IdentityRequestContext: ChildRequestContext, AuthRequestContext {
    package typealias ParentContext = BasicRequestContext

    package var coreContext: CoreRequestContextStorage
    package var identity: UserIdentity?

    package init(context: BasicRequestContext) throws {
        self.coreContext = context.coreContext
        self.identity = nil
    }
}
SWIFT
cat > acme-api/Sources/API/Controllers/ItemController.swift <<'SWIFT'
package import CatalogProtos
import GRPCCore
package import Hummingbird

package struct ItemController: Sendable {
    private let client: Acme_Catalog_V1_ItemService.ClientProtocol

    package init(client: Acme_Catalog_V1_ItemService.ClientProtocol) {
        self.client = client
    }

    package func addPublicRoutes(to group: RouterGroup<BasicRequestContext>) {
        group
            .get(use: listItems)
            .get(":id", use: getItem)
    }

    package func addAuthenticatedRoutes(to group: RouterGroup<IdentityRequestContext>) {
    }

    @Sendable
    private func listItems(_ request: Request, context: BasicRequestContext) async throws -> [ItemResponse] {
        let response = try await client.listItems(.init())
        return response.items.map(ItemResponse.init(item:))
    }

    @Sendable
    private func getItem(_ request: Request, context: BasicRequestContext) async throws -> ItemResponse {
        let id = try context.parameters.require("id")
        let response = try await client.getItem(.with { $0.id = id })
        return ItemResponse(item: response.item)
    }
}
SWIFT
cat > acme-api/Sources/API/AcmeAPI.swift <<'SWIFT'
package import AcmeAuthentication
package import Authentication
import AuthenticationHummingbird
package import Hummingbird
import HummingbirdAuth

package func buildRouter(
    itemController: ItemController,
    userAuthenticator: some Authenticator<String, UserIdentity>
) -> Router<BasicRequestContext> {
    let router = Router(context: BasicRequestContext.self)
    router.add(middleware: ErrorMiddleware())

    let v1 = router.group("v1")

    // Tier 1 — no caller.
    itemController.addPublicRoutes(to: v1.group("items"))

    // Tier 2 — a caller if there is one.
    let identified = v1.group(context: IdentityRequestContext.self)
        .add(middleware: BearerAuthenticationMiddleware<IdentityRequestContext>(authenticator: userAuthenticator))

    // Tier 3 — a caller is required.
    let authenticated = identified.add(middleware: IsAuthenticatedMiddleware())
    itemController.addAuthenticatedRoutes(to: authenticated.group("items"))

    return router
}
SWIFT
