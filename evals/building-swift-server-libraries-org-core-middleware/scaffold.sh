#!/bin/bash
# Lays down an abridged acme-core organization layer with its gRPC tenant binding.
set -euo pipefail
mkdir -p Sources/AcmeAuthentication Sources/AcmePersistence Tests/AcmeCoreTests
cat > Package.swift <<'PKG'
// swift-tools-version: 6.3
// Copyright (c) 2026 Acme
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
    name: "acme-core",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .library(name: "AcmeAuthentication", targets: ["AcmeAuthentication"]),
        .library(name: "AcmePersistence", targets: ["AcmePersistence"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swift-microservices/swift-authentication.git", from: "0.3.0"),
        .package(url: "https://github.com/swift-microservices/swift-persistence-postgres.git", from: "0.2.1"),
        .package(url: "https://github.com/apple/swift-service-context.git", from: "1.3.0"),
        .package(url: "https://github.com/grpc/grpc-swift-2.git", from: "2.4.0"),
    ],
    targets: [
        .target(
            name: "AcmeAuthentication",
            dependencies: [
                .product(name: "Authentication", package: "swift-authentication"),
                .product(name: "ServiceContextModule", package: "swift-service-context"),
            ],
            swiftSettings: swiftSettings
        ),
        .target(
            name: "AcmePersistence",
            dependencies: [
                "AcmeAuthentication",
                .product(name: "GRPCCore", package: "grpc-swift-2"),
                .product(name: "PersistencePostgres", package: "swift-persistence-postgres"),
                .product(name: "ServiceContextModule", package: "swift-service-context"),
            ],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "AcmeCoreTests",
            dependencies: [
                "AcmeAuthentication",
                "AcmePersistence",
                .product(name: "Authentication", package: "swift-authentication"),
                .product(name: "GRPCCore", package: "grpc-swift-2"),
                .product(name: "PersistencePostgres", package: "swift-persistence-postgres"),
                .product(name: "ServiceContextModule", package: "swift-service-context"),
            ],
            swiftSettings: swiftSettings
        ),
    ],
    swiftLanguageModes: [.v6]
)
PKG
cat > Sources/AcmeAuthentication/UserIdentity.swift <<'SWIFT'
// Copyright (c) 2026 Acme
// SPDX-License-Identifier: LicenseRef-Proprietary
// See LICENSE for license information.

#if canImport(FoundationEssentials)
public import FoundationEssentials
#else
public import Foundation
#endif

/// The verified user a token proves. Abridged: the JWT payload conformance is omitted.
public struct UserIdentity: Sendable, Equatable {
    /// The user's identifier, the token's `sub`.
    public let userId: UUID

    /// Creates an identity for a verified user.
    public init(userId: UUID) {
        self.userId = userId
    }
}
SWIFT
cat > Sources/AcmeAuthentication/ServiceContext+User.swift <<'SWIFT'
// Copyright (c) 2026 Acme
// SPDX-License-Identifier: LicenseRef-Proprietary
// See LICENSE for license information.

public import Authentication
public import ServiceContextModule

extension ServiceContext {
    /// The verified user the bearer interceptor or middleware bound, if any.
    public var user: Principal<UserIdentity, String>? {
        get { self[PrincipalKey<UserIdentity, String>.self] }
        set { self[PrincipalKey<UserIdentity, String>.self] = newValue }
    }
}
SWIFT
cat > Sources/AcmePersistence/PostgresSettings+User.swift <<'SWIFT'
// Copyright (c) 2026 Acme
// SPDX-License-Identifier: LicenseRef-Proprietary
// See LICENSE for license information.

public import AcmeAuthentication
public import PersistencePostgres

extension PostgresSettings {
    /// The one setting the tenant policies read, `app.caller_user_id`, lowercased.
    public static func user(_ user: UserIdentity) -> PostgresSettings {
        ["app.caller_user_id": user.userId.uuidString.lowercased()]
    }
}
SWIFT
cat > Sources/AcmePersistence/UserSettingsInterceptor.swift <<'SWIFT'
// Copyright (c) 2026 Acme
// SPDX-License-Identifier: LicenseRef-Proprietary
// See LICENSE for license information.

import AcmeAuthentication
public import GRPCCore
import PersistencePostgres
import ServiceContextModule

/// Turns the bound user into the setting every transaction of the call begins with.
///
/// Apply it after the bearer interceptor, to the same services. A call with no user bound
/// continues with no user settings, which the policies treat as no rows.
public struct UserSettingsInterceptor: ServerInterceptor {
    /// Creates the interceptor.
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
        guard var serviceContext = ServiceContext.current, let user = serviceContext.user else {
            return try await next(request, context)
        }

        serviceContext.postgresSettings = .user(user.identity)

        return try await ServiceContext.withValue(serviceContext) {
            try await next(request, context)
        }
    }
}
SWIFT
cat > Tests/AcmeCoreTests/UserSettingsInterceptorTests.swift <<'SWIFT'
// Copyright (c) 2026 Acme
// SPDX-License-Identifier: LicenseRef-Proprietary
// See LICENSE for license information.

// Abridged: the interceptor's tests call `intercept` directly with a hand-built request.
SWIFT
cat > AGENTS.md <<'MD'
# AGENTS.md

`acme-core` supplies Acme's shared user identity, the tenant setting the row-level security
policies read, and its bindings. It is a library consumed by tag.

## Product boundaries

| Product | Holds | Linked by |
| --- | --- | --- |
| `AcmeAuthentication` | User identity and `ServiceContext.user` | Domain targets, adapters, composition roots |
| `AcmePersistence` | The user Postgres setting and its transport bindings | Processes with a database |

Domain targets do not acquire transport dependencies. Composition, configuration, and
certificate handling belong to each application.

## Releases

Every pull request carries exactly one SemVer label; Auto Release runs by hand on `main`.
The latest release is 0.4.0.
MD
