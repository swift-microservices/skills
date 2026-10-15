# The organization core, in code

## Contents

- [Layout](#layout)
- [Manifest](#manifest)
- [`<Project>Authentication`](organization-core-authentication.md#projectauthentication)
- [`<Project>Persistence`](organization-core-persistence.md#projectpersistence)
- [The Vapor form](organization-core-persistence.md#the-vapor-form)
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

A project that serves only gRPC drops Hummingbird and the middleware; a Vapor project replaces them with [the Vapor form](organization-core-persistence.md#the-vapor-form). An mTLS contract suite, where the core documents mTLS composition, is a second test target (`<Project>MTLSTests`) holding its own NIO, TLS, and certificate dependencies so `<Project>CoreTests` does not acquire them.

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
