# The organization core, in code

## Contents

- [Layout](#layout)
- [Manifest](#manifest)
- [`<Project>Authentication`](#projectauthentication)
- [`<Project>Persistence`](#projectpersistence)
- [The Vapor form](#the-vapor-form)
- [`<Project>Testing`](#projecttesting)
- [Tests](#tests)

The complete `<project>-core`: replace `<project>`, `<Project>`, `<owner>`, and `<year>`, and it builds as written. What each product is for, and when the package exists at all, is in [organization-layer.md](organization-layer.md). Every file starts with the compact license header shown in the manifest, and every public declaration carries a `///` comment; the blocks below abridge both.

## Layout

```text
<project>-core/
  Package.swift
  AGENTS.md                          # the canonical project profile ("<Project>'s choices")
  README.md
  LICENSE
  .gitignore                         # .build, .swiftpm, Package.resolved
  .swift-format
  .license_header_template
  .licenseignore
  .spi.yml                           # public repositories only
  .github/
  Sources/
    <Project>Authentication/
      UserRole.swift
      UserIdentity.swift
      JWT+EdDSA.swift
      OperationContext+User.swift
      Documentation.docc/<Project>Authentication.md
    <Project>Persistence/
      PostgresSettings+User.swift
      UserSettingsInterceptor.swift
      UserSettingsMiddleware.swift
      Documentation.docc/<Project>Persistence.md
    <Project>Testing/
      MockDatabase.swift
      MockUserAuthenticator.swift
      Documentation.docc/<Project>Testing.md
  Tests/
    <Project>CoreTests/              # one target across the three modules
    <Project>MTLSTests/              # optional: the mTLS composition contract suite
```

## Manifest

Each target declares exactly the products its files import; the `swiftSettings` array is the shared one from the writing skill's [swift-settings.md](../../writing-swift-server-code/references/swift-settings.md), attached to every target.

```swift
// swift-tools-version: 6.3
// Copyright (c) <year> <owner>
// SPDX-License-Identifier: LicenseRef-Proprietary
// See LICENSE for license information.

import PackageDescription

let swiftSettings: [SwiftSetting] = [
    .enableUpcomingFeature("ExistentialAny"),
    .enableUpcomingFeature("MemberImportVisibility"),
    .enableUpcomingFeature("InternalImportsByDefault"),
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
]

let package = Package(
    name: "<project>-core",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .library(name: "<Project>Authentication", targets: ["<Project>Authentication"]),
        .library(name: "<Project>Persistence", targets: ["<Project>Persistence"]),
        .library(name: "<Project>Testing", targets: ["<Project>Testing"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swift-microservices/swift-persistence.git", from: "0.2.0"),
        .package(url: "https://github.com/swift-microservices/swift-persistence-postgres.git", from: "0.3.0"),
        .package(url: "https://github.com/swift-microservices/swift-authentication.git", from: "0.4.0"),
        .package(url: "https://github.com/swift-microservices/swift-authentication-jwt.git", from: "0.3.2"),
        .package(url: "https://github.com/swift-microservices/swift-operation-context.git", from: "0.1.0"),
        .package(url: "https://github.com/vapor/jwt-kit.git", from: "5.7.1"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.6.0"),
        .package(url: "https://github.com/grpc/grpc-swift-2.git", from: "2.4.0"),
        .package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "2.28.0", traits: []),
    ],
    targets: [
        // Identity. Every Core target links it, so it carries no transport.
        .target(
            name: "<Project>Authentication",
            dependencies: [
                .product(name: "Authentication", package: "swift-authentication"),
                .product(name: "AuthenticationJWT", package: "swift-authentication-jwt"),
                // Direct: `UserIdentity` does `public import JWTKit`.
                .product(name: "JWTKit", package: "jwt-kit"),
                .product(name: "Logging", package: "swift-log"),
                .product(name: "OperationContext", package: "swift-operation-context"),
            ],
            swiftSettings: swiftSettings
        ),
        // Where identity meets the database. Only executables link it.
        .target(
            name: "<Project>Persistence",
            dependencies: [
                "<Project>Authentication",
                .product(name: "Authentication", package: "swift-authentication"),
                .product(name: "GRPCCore", package: "grpc-swift-2"),
                .product(name: "Hummingbird", package: "hummingbird"),
                .product(name: "PersistencePostgres", package: "swift-persistence-postgres"),
                .product(name: "OperationContext", package: "swift-operation-context"),
            ],
            swiftSettings: swiftSettings
        ),
        // Shared test doubles. Test targets only.
        .target(
            name: "<Project>Testing",
            dependencies: [
                "<Project>Authentication",
                .product(name: "Persistence", package: "swift-persistence"),
                .product(name: "Authentication", package: "swift-authentication"),
            ],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "<Project>CoreTests",
            dependencies: [
                "<Project>Authentication",
                "<Project>Persistence",
                "<Project>Testing",
                .product(name: "Authentication", package: "swift-authentication"),
                .product(name: "AuthenticationJWT", package: "swift-authentication-jwt"),
                .product(name: "GRPCCore", package: "grpc-swift-2"),
                .product(name: "Hummingbird", package: "hummingbird"),
                .product(name: "HummingbirdTesting", package: "hummingbird"),
                .product(name: "JWTKit", package: "jwt-kit"),
                .product(name: "Logging", package: "swift-log"),
                .product(name: "Persistence", package: "swift-persistence"),
                .product(name: "PersistencePostgres", package: "swift-persistence-postgres"),
                .product(name: "OperationContext", package: "swift-operation-context"),
            ],
            swiftSettings: swiftSettings
        ),
    ],
    swiftLanguageModes: [.v6]
)
```

A project that serves only gRPC drops Hummingbird and the middleware; a Vapor project replaces them with [the Vapor form](#the-vapor-form). An mTLS contract suite, where the core documents mTLS composition, is a second test target (`<Project>MTLSTests`) holding its own NIO, TLS, and certificate dependencies so `<Project>CoreTests` does not acquire them.

## `<Project>Authentication`

`UserRole.swift`: an open string, so a role this build does not know is never read as an administrator.

```swift
/// A user's role, as the token carries it.
public struct UserRole: RawRepresentable, Hashable, Codable, ExpressibleByStringLiteral, Sendable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(_ rawValue: String) {
        self.init(rawValue: rawValue)
    }

    public init(stringLiteral value: StringLiteralType) {
        self.init(rawValue: value)
    }
}

extension UserRole {
    public static let user: UserRole = "user"
    public static let admin: UserRole = "admin"
}
```

`UserIdentity.swift`: the JWT payload. `sub` decodes straight into a `UUID`, so a token whose subject is not a user id fails to decode.

```swift
public import JWTKit

#if canImport(FoundationEssentials)
public import FoundationEssentials
#else
public import Foundation
#endif

/// A user as their access token names them: who, in what role, issued by whom, until when.
public struct UserIdentity: JWTPayload, Equatable, Sendable {
    public let userId: UUID
    public let role: UserRole
    public let iss: IssuerClaim
    public let iat: IssuedAtClaim
    public let exp: ExpirationClaim

    public init(userId: UUID, role: UserRole, issuer: String, issuedAt: Date, expiration: Date) {
        self.userId = userId
        self.role = role
        self.iss = IssuerClaim(value: issuer)
        self.iat = IssuedAtClaim(value: issuedAt)
        self.exp = ExpirationClaim(value: expiration)
    }

    public var issuer: String { iss.value }
    public var issuedAt: Date { iat.value }
    public var expiration: Date { exp.value }

    public func verify(using algorithm: some JWTAlgorithm) throws {
        try exp.verifyNotExpired()
    }

    private enum CodingKeys: String, CodingKey {
        case userId = "sub"
        case role
        case iss
        case iat
        case exp
    }
}
```

Add an audience claim and check it in `verify(using:)` when the deployment uses one; nothing else rides in the token.

`JWT+EdDSA.swift`: the conveniences take key values; loading key files stays in each executable.

```swift
public import AuthenticationJWT
public import JWTKit

extension JWTIssuer where Payload == UserIdentity {
    /// The issuer of user tokens, over the EdDSA private key only the authenticating service holds.
    public init(privateKey: EdDSA.PrivateKey) async {
        let keys = JWTKeyCollection()
        await keys.add(eddsa: privateKey)
        self.init(keys: keys)
    }
}

extension JWTAuthenticator where Payload == UserIdentity {
    /// The authenticator of user tokens, over the EdDSA public key every service holds.
    public init(publicKey: EdDSA.PublicKey) async {
        let keys = JWTKeyCollection()
        await keys.add(eddsa: publicKey)
        self.init(keys: keys)
    }
}
```

`OperationContext+User.swift`: the named accessor over swift-authentication's generic key, and the logging metadata provider an executable passes to `LoggingSystem.bootstrap`.

```swift
public import Authentication
public import Logging
public import OperationContext

extension OperationContext {
    /// The verified user behind the current request, bound by the bearer interceptor or middleware.
    ///
    /// `nil` is not a failure: the bindings identify a user without requiring one.
    public var user: Principal<UserIdentity, String>? {
        get { self[PrincipalKey<UserIdentity, String>.self] }
        set { self[PrincipalKey<UserIdentity, String>.self] = newValue }
    }
}

extension Logger.MetadataProvider {
    /// Puts the bound user's id on every log line, as `user_id`; adds nothing when no user is
    /// bound, and never the credential.
    public static let user = Logger.MetadataProvider {
        guard let user = OperationContext.current.user else {
            return [:]
        }

        return ["user_id": "\(user.identity.userId)"]
    }
}
```

## `<Project>Persistence`

`PostgresSettings+User.swift`: the one setting the tenant policies read. Where the tenant is an organization, the setting and the helper name that id instead.

```swift
public import <Project>Authentication
public import PersistencePostgres

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

extension PostgresSettings {
    /// The setting the row-level security policies read, `app.caller_user_id`, lowercased
    /// because that is how Postgres prints a `uuid` back.
    public static func user(_ user: UserIdentity) -> PostgresSettings {
        ["app.caller_user_id": user.userId.uuidString.lowercased()]
    }
}
```

`UserSettingsInterceptor.swift`: applied after the bearer interceptor, to the same `<Entity>Service` descriptors, never an internal one. `next` matches GRPCCore's `@concurrent @Sendable` requirement exactly.

```swift
import Authentication
import <Project>Authentication
public import GRPCCore
import OperationContext
import PersistencePostgres

/// Turns the bound user into the setting every transaction of the call begins with.
///
/// A call with no user bound continues unchanged, which the policies treat as no rows.
public struct UserSettingsInterceptor: ServerInterceptor {
    public init() {}

    public func intercept<Input: Sendable, Output: Sendable>(
        request: StreamingServerRequest<Input>,
        context: ServerContext,
        next:
            @concurrent @Sendable (
                _ request: StreamingServerRequest<Input>,
                _ context: ServerContext
            ) async throws -> StreamingServerResponse<Output>
    ) async throws -> StreamingServerResponse<Output> {
        var operationContext = OperationContext.current
        guard let user = operationContext.user else {
            return try await next(request, context)
        }

        operationContext.postgresSettings = .user(user.identity)

        return try await OperationContext.withContext(operationContext) {
            try await next(request, context)
        }
    }
}
```

`UserSettingsMiddleware.swift`: the Hummingbird form, added after `BearerAuthenticationMiddleware` on the identifying tier. `next` matches `RouterMiddleware`'s `@concurrent` requirement.

```swift
import Authentication
import <Project>Authentication
public import Hummingbird
import OperationContext
import PersistencePostgres

/// Turns the bound user into the setting every transaction of the request begins with.
///
/// A request with no user bound continues unchanged, which the policies treat as no rows.
public struct UserSettingsMiddleware<Context: RequestContext>: RouterMiddleware {
    public init() {}

    public func handle(
        _ request: Request,
        context: Context,
        next: @concurrent (Request, Context) async throws -> Response
    ) async throws -> Response {
        var operationContext = OperationContext.current
        guard let user = operationContext.user else {
            return try await next(request, context)
        }

        operationContext.postgresSettings = .user(user.identity)

        return try await OperationContext.withContext(operationContext) {
            try await next(request, context)
        }
    }
}
```

## The Vapor form

On a Vapor project, `<Project>Persistence` depends on Vapor and AuthenticationVapor (swift-authentication-vapor) in place of Hummingbird, and `UserSettingsMiddleware` reads and writes `request.operationContext`, because Vapor 4 does not carry a task-local from middleware to the route; routes bind `req.operationContext` around work that reads `OperationContext.current`.

```swift
import Authentication
import AuthenticationVapor
import <Project>Authentication
import OperationContext
import PersistencePostgres
public import Vapor

/// Turns the bound user into the setting every transaction of the request begins with.
public struct UserSettingsMiddleware: AsyncMiddleware {
    public init() {}

    public func respond(to request: Request, chainingTo next: any AsyncResponder) async throws -> Response {
        var operationContext = request.operationContext
        guard let user = operationContext.user else {
            return try await next.respond(to: request)
        }

        operationContext.postgresSettings = .user(user.identity)
        request.operationContext = operationContext

        return try await OperationContext.withContext(operationContext) {
            try await next.respond(to: request)
        }
    }
}
```

Vapor's `BearerAuthenticationMiddleware<Identity>` needs `UserIdentity: Authenticatable`. Declare that conformance in the HTTP target that installs the middleware, `extension UserIdentity: @retroactive Authenticatable {}`, never in `<Project>Authentication`, which would put Vapor in every Core target.

## `<Project>Testing`

`MockDatabase.swift`: no transaction, a fixed scope, caller-isolated like the real one.

```swift
public import Persistence

/// A `Database` with no transaction and a fixed scope, for use-case tests over mock repositories.
///
/// The operation keeps the caller's isolation across suspension; unlike the real database, a
/// throwing operation rolls nothing back.
public struct MockDatabase<Scope: Sendable>: Database {
    public let scope: Scope

    public init(scope: Scope) {
        self.scope = scope
    }

    public func withTransaction<T: Sendable>(
        _ operation: (Scope) async throws -> T
    ) async throws -> T {
        try await operation(scope)
    }
}
```

`MockUserAuthenticator.swift`: a table of tokens, so a handler test sends `Bearer admin-token` without minting a key.

```swift
public import Authentication
public import <Project>Authentication

/// An `Authenticator<String, UserIdentity>` over a table; a token not in it is refused.
public struct MockUserAuthenticator: Authenticator {
    /// The error for a token the table does not hold.
    public struct UnknownToken: Error, Equatable {
        public let token: String

        public init(token: String) {
            self.token = token
        }
    }

    private let users: [String: UserIdentity]

    public init(_ users: [String: UserIdentity]) {
        self.users = users
    }

    public func authenticate(_ token: String) async throws -> UserIdentity {
        guard let user = users[token] else {
            throw UnknownToken(token: token)
        }

        return user
    }
}
```

## Tests

`<Project>CoreTests` proves, without a server or a database:

- **Wire claims.** A token the issuer mints decodes to exactly `["sub", "role", "iss", "iat", "exp"]`, `sub` the user id's UUID string and `role` its raw value.
- **EdDSA round trip.** `JWTIssuer<UserIdentity>(privateKey:)` mints, `JWTAuthenticator<UserIdentity>(publicKey:)` returns an equal identity (build dates in whole seconds; a token carries no fraction).
- **Expired token.** A token with `exp` in the past throws `JWTError`.
- **Non-UUID subject.** A payload signed with the same key whose `sub` is `"not-a-uuid"` throws `JWTError`.
- **Metadata scoping.** Inside `withContext(OperationContext())` the `.user` provider is empty; inside a nested scope with a principal it is exactly `["user_id": …]` with no credential; after the scope, both the user and the metadata are gone.
- **Interceptor, both branches.** Call `intercept` directly with a hand-built request and a `next` closure that suspends and records `OperationContext.current`: a bound user yields exactly `.user(identity)` (replacing, not merging, settings the enclosing context carried) and keeps the principal; no user yields no settings; after the call the enclosing context is unchanged.
- **Middleware, both branches.** HummingbirdTesting's `.router` framework with a route that suspends and reports `postgresSettings`, bound and unbound, and the enclosing context restored after `execute`. A Vapor form uses VaporTesting and asserts `request.operationContext`.
- **Mock isolation.** `MockDatabase` from a custom actor and from `@MainActor`, suspending inside the closure with isolation checked on both sides, a thrown error propagating unchanged, per [the isolation contract tests](testing.md#isolation-contract-tests); `MockUserAuthenticator` returns a listed user and throws `UnknownToken(token:)` for any other.

The interceptor test's request and context:

```swift
let request = StreamingServerRequest<String>(
    metadata: [:],
    messages: RPCAsyncSequence(wrapping: AsyncThrowingStream { $0.finish() })
)
let serverContext = ServerContext(
    descriptor: .init(fullyQualifiedService: "test.Service", method: "Call"),
    remotePeer: "client",
    localPeer: "server",
    cancellation: .init()
)
```
