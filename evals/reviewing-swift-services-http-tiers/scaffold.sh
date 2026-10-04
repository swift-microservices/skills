#!/bin/bash
# Lays down an abridged HTTP monolith whose surface the reviewer audits.
set -euo pipefail
mkdir -p Sources/AcmeHTTP/Contexts Sources/NotesCore/Notes Sources/NotesHTTP/Controllers Sources/NotesHTTP/Schemas/Responses Sources/Acme/Serve
cat > Package.swift <<'PKG'
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
        .package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "2.27.0", traits: ["ConfigurationSupport"]),
        .package(url: "https://github.com/hummingbird-project/hummingbird-auth.git", from: "2.5.0"),
        .package(url: "https://github.com/apple/swift-openapi-generator.git", from: "1.13.0"),
        .package(url: "https://github.com/apple/swift-openapi-runtime.git", from: "1.12.1", traits: []),
        .package(url: "https://github.com/swift-microservices/swift-persistence.git", from: "0.2.0"),
        .package(url: "https://github.com/swift-microservices/swift-authentication.git", from: "0.3.0"),
        .package(url: "https://github.com/swift-microservices/swift-authentication-jwt.git", from: "0.3.0"),
        .package(url: "https://github.com/swift-microservices/swift-authentication-hummingbird.git", from: "0.3.0"),
        .package(url: "https://github.com/acme/acme-core.git", from: "0.1.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.15.0"),
    ],
    targets: [
        .target(name: "AcmeHTTP", dependencies: [
            .product(name: "Hummingbird", package: "hummingbird"),
            .product(name: "HummingbirdAuth", package: "hummingbird-auth"),
            .product(name: "AcmeAuthentication", package: "acme-core"),
        ], swiftSettings: swiftSettings),
        .target(name: "NotesCore", dependencies: [
            .product(name: "Persistence", package: "swift-persistence"),
            .product(name: "AcmeAuthentication", package: "acme-core"),
            .product(name: "Logging", package: "swift-log"),
        ], swiftSettings: swiftSettings),
        .target(name: "NotesHTTP", dependencies: [
            "NotesCore", "AcmeHTTP",
            .product(name: "Hummingbird", package: "hummingbird"),
            .product(name: "HummingbirdAuth", package: "hummingbird-auth"),
            .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
            .product(name: "AcmeAuthentication", package: "acme-core"),
            .product(name: "Logging", package: "swift-log"),
        ], swiftSettings: swiftSettings, plugins: [.plugin(name: "OpenAPIGenerator", package: "swift-openapi-generator")]),
        .executableTarget(name: "Acme", dependencies: [
            "AcmeHTTP", "NotesCore", "NotesHTTP",
            .product(name: "Hummingbird", package: "hummingbird"),
            .product(name: "HummingbirdAuth", package: "hummingbird-auth"),
            .product(name: "Authentication", package: "swift-authentication"),
            .product(name: "AuthenticationJWT", package: "swift-authentication-jwt"),
            .product(name: "AuthenticationHummingbird", package: "swift-authentication-hummingbird"),
            .product(name: "AcmeAuthentication", package: "acme-core"),
            .product(name: "AcmePersistence", package: "acme-core"),
            .product(name: "Logging", package: "swift-log"),
        ], swiftSettings: swiftSettings),
    ],
    swiftLanguageModes: [.v6]
)
PKG
cat > Sources/AcmeHTTP/Contexts/IdentityRequestContext.swift <<'SWIFT'
package import AcmeAuthentication
package import Hummingbird
package import HummingbirdAuth

package struct IdentityRequestContext: ChildRequestContext, AuthRequestContext {
    package typealias ParentContext = BasicRequestContext

    package var coreContext: CoreRequestContextStorage
    package var identity: UserIdentity?

    package init(context: BasicRequestContext) throws {
        self.coreContext = .init(source: context)
        self.identity = nil
    }
}
SWIFT
cat > Sources/AcmeHTTP/Contexts/AdminRequestContext.swift <<'SWIFT'
package import AcmeAuthentication
package import Hummingbird

package struct AdminRequestContext: ChildRequestContext {
    package typealias ParentContext = IdentityRequestContext

    package var coreContext: CoreRequestContextStorage
    package let identity: UserIdentity

    package init(context: IdentityRequestContext) throws {
        guard let identity = context.identity else {
            throw HTTPError(.unauthorized, message: "Authentication is required.")
        }
        guard identity.role == .admin else {
            throw HTTPError(.forbidden, message: "This operation requires an administrator.")
        }
        self.coreContext = context.coreContext
        self.identity = identity
    }
}
SWIFT
cat > Sources/NotesHTTP/Schemas/Responses/NoteResponse+Schema.swift <<'SWIFT'
import NotesCore

extension Components.Schemas.NoteList {
    init(notes: [Note]) {
        self.init(items: notes.compactMap { note in
            guard !note.body.isEmpty else {
                return nil
            }
            return Components.Schemas.Note(id: note.id.uuidString.lowercased(), body: note.body)
        })
    }
}
SWIFT
cat > Sources/NotesHTTP/Controllers/NoteController.swift <<'SWIFT'
package import AcmeHTTP
package import Hummingbird
package import NotesCore

package struct NoteController: Sendable {
    private let listNotesUseCase: any ListNotesUseCaseProtocol

    package init(listNotesUseCase: any ListNotesUseCaseProtocol) {
        self.listNotesUseCase = listNotesUseCase
    }

    package func addAuthenticatedRoutes(to group: RouterGroup<IdentityRequestContext>) {
        group.get(use: listNotes)
    }

    @Sendable
    private func listNotes(_ request: Request, context: IdentityRequestContext) async throws -> Components.Schemas.NoteList {
        let subject = try context.requireIdentity()
        let notes = try await listNotesUseCase(subject: subject)
        return Components.Schemas.NoteList(notes: notes)
    }
}
SWIFT
cat > Sources/Acme/Serve/Serve.swift <<'SWIFT'
import AcmeAuthentication
import AcmeHTTP
import AcmePersistence
import AuthenticationHummingbird
import Hummingbird
import HummingbirdAuth
import NotesHTTP

// Abridged: configuration, logging, infrastructure, and lifecycle are omitted.
func makeRouter(
    sessionController: SessionController,
    noteController: NoteController,
    userAuthenticator: some Authenticator<String, UserIdentity>
) -> Router<BasicRequestContext> {
    // MARK: - Router
    let router = Router(context: BasicRequestContext.self)
    router.add(middleware: ErrorMiddleware())

    let v1 = router.group("v1")

    // Tier 1: no caller.
    sessionController.addSignInRoute(to: v1.group("auth"))
    v1.get("health") { _, _ in HTTPResponse.Status.ok }

    // Tier 2: a caller if there is one.
    let identified = v1.group(context: IdentityRequestContext.self)
        .add(middleware: BearerAuthenticationMiddleware<IdentityRequestContext>(authenticator: userAuthenticator))
        .add(middleware: UserSettingsMiddleware())
    sessionController.addRefreshRoute(to: identified.group("auth"))

    // Tier 3: a caller is required.
    let authenticated = identified.add(middleware: IsAuthenticatedMiddleware())
    noteController.addAuthenticatedRoutes(to: authenticated.group("notes"))

    return router
}
SWIFT
