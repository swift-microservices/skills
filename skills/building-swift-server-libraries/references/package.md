# The library package

## Contents

- One concept, one dependency set
- The family
- Naming
- The manifest
- Dependencies and floors
- Platforms
- Versions, tags, and releases
- Splitting and adding packages

## One concept, one dependency set

A reusable library holds one concept and is cut by what it links, so a target that imports it acquires exactly the technology its name promises and nothing behind it. `Persistence` depends on nothing, not even Foundation, so a domain target can link the transaction boundary without a driver; the driver is `PersistencePostgres` in its own package. `Authentication` depends only on swift-service-context, so every proof and every transport binding can share its vocabulary without sharing each other's dependencies.

The test of where a type belongs is what it would make a consumer link. A Postgres type in the abstraction package drags PostgresNIO into every domain target; a Hummingbird middleware in the JWT package drags a server framework into every issuer. When a new type needs a dependency the package does not already have, it almost always belongs in another package.

Keep the generic machinery generic: a swift-microservices library knows nothing of an organization's claims, roles, settings names, or contracts. Those belong to the organization layer (see [organization-layer.md](organization-layer.md)).

## The family

| Package | Product | Holds | Depends on |
| --- | --- | --- | --- |
| swift-persistence | `Persistence` | `Database<Scope>`, the transaction boundary | nothing |
| swift-persistence-postgres | `PersistencePostgres` | `PostgresDatabase`, `PostgresScope`, `PostgresSettings` and its `ServiceContext` key, `PostgresClient.withClient` | swift-persistence, PostgresNIO, swift-log, swift-service-context |
| swift-authentication | `Authentication` | `Authenticator`, `CredentialIssuer`, `Principal`, `PrincipalKey` | swift-service-context |
| swift-authentication-jwt | `AuthenticationJWT` | `JWTAuthenticator<Payload>`, `JWTIssuer<Payload>` over a `JWTKeyCollection` | swift-authentication, jwt-kit |
| swift-authentication-grpc | `AuthenticationGRPC` | `BearerAuthenticationInterceptor`, `BearerPropagationInterceptor`, `Metadata.bearer` | swift-authentication, grpc-swift-2, swift-service-context |
| swift-authentication-hummingbird | `AuthenticationHummingbird` | `BearerAuthenticationMiddleware<Context>` | swift-authentication, Hummingbird (`traits: []`), HummingbirdAuth, swift-service-context |
| swift-authentication-vapor | `AuthenticationVapor` | `BearerAuthenticationMiddleware<Identity>` for Vapor 4 | swift-authentication, Vapor, swift-service-context |
| swift-openapi-token-authentication | `OpenAPITokenAuthentication` | a client-side OpenAPI `ClientMiddleware` with an access/refresh token session, for apps and SDKs calling an HTTP surface | swift-openapi-runtime (`traits: []`), swift-http-types |

An abstraction package and its drivers or bindings are separate packages that depend on the abstraction by tag. A binding package binds a principal or a setting on its transport and decides nothing: authorization belongs to the owning use case, and a policy name belongs to the organization layer.

Before adding a package, check whether the concept is already one of these, and whether it is generic. Mechanisms that would differ between two consumers, such as configuration readers, transport-security factories, composition roots, and mock repositories, are wiring each application owns, not a library.

## Naming

- Repository and package: `swift-<concept>` for an abstraction, `swift-<concept>-<technology>` for its driver or binding, lowercase: `swift-persistence-postgres`, `swift-authentication-grpc`.
- Product and module: the concept in upper camel case, then the technology: `Persistence`, `PersistencePostgres`, `AuthenticationGRPC`. A product carries no organization prefix; an organization-layer product does (`<Project>Authentication`).
- Types: the concept they provide, never a framework's generic vocabulary (`PostgresDatabase`, `JWTAuthenticator`, `BearerPropagationInterceptor`), and identifiers spelled `ID` in type names and `Id` in values (`userId`).
- A client library named for the technology it plugs into keeps that technology's prefix: swift-openapi-token-authentication (`OpenAPITokenAuthentication`) is middleware for Swift OpenAPI Generator's clients, not a binding of swift-authentication, and does not depend on it.
- A test target is `<Module>Tests`; a second test target that needs heavier dependencies is named for what it proves (`<Project>MTLSTests`).

## The manifest

```swift
// swift-tools-version: 6.3
// Copyright (c) 2026 Zaid Rahhawi
// SPDX-License-Identifier: MIT
// See LICENSE for license information.

import PackageDescription

let swiftSettings: [SwiftSetting] = [
    // https://github.com/apple/swift-evolution/blob/main/proposals/0335-existential-any.md
    .enableUpcomingFeature("ExistentialAny"),

    // https://github.com/swiftlang/swift-evolution/blob/main/proposals/0444-member-import-visibility.md
    .enableUpcomingFeature("MemberImportVisibility"),

    // https://github.com/swiftlang/swift-evolution/blob/main/proposals/0409-access-level-on-imports.md
    .enableUpcomingFeature("InternalImportsByDefault"),

    // https://github.com/swiftlang/swift-evolution/blob/main/proposals/0461-async-function-isolation.md
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
]

let package = Package(
    name: "swift-persistence-postgres",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .library(
            name: "PersistencePostgres",
            targets: ["PersistencePostgres"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/swift-microservices/swift-persistence.git", from: "0.2.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.15.0"),
        .package(url: "https://github.com/apple/swift-service-context.git", from: "1.3.0"),
        .package(url: "https://github.com/vapor/postgres-nio.git", from: "1.33.1"),
    ],
    targets: [
        .target(
            name: "PersistencePostgres",
            dependencies: [
                .product(name: "Persistence", package: "swift-persistence"),
                .product(name: "Logging", package: "swift-log"),
                .product(name: "ServiceContextModule", package: "swift-service-context"),
                .product(name: "PostgresNIO", package: "postgres-nio"),
            ],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "PersistencePostgresTests",
            dependencies: [
                .target(name: "PersistencePostgres")
            ],
            swiftSettings: swiftSettings
        ),
    ],
    swiftLanguageModes: [.v6]
)
```

- The tools-version line is first, then the compact license header, then `import PackageDescription`.
- One shared settings array, each feature commented with its proposal, attached to every target and test target; the [Swift settings](../../writing-swift-server-code/references/swift-settings.md) explain each.
- One library product per package by default, exposing the one module consumers import. A second product is justified only by a second dependency set a consumer must be able to avoid; a test-support product is an organization-layer pattern (`<Project>Testing`), linked by test targets only. The organization layer records two more exceptions: `<project>-protos` has one `<Module>Protos` product per contract, so a consumer imports only the contracts it calls, and `<Project>Persistence` bundles its gRPC and Hummingbird bindings (and the Vapor one on a Vapor project) because only executables link it (see [organization-layer.md](organization-layer.md)).
- Every target declares exactly the products it imports, and every declared package is used. Use `.package(url:from:)` with the full `.git` URL.
- No unsafe flags, no `@preconcurrency` imports, no default MainActor isolation: a consumer cannot build a package whose manifest uses unsafe flags as a dependency.

## Dependencies and floors

A library's `from:` is the oldest release that has every API and fix the library relies on, not the newest release available: a library's floor constrains every application that resolves it, and an application chooses newer releases for itself. Raise a floor when the library starts to rely on something newer, and say why in the commit: `Require jwt-kit 5.7.1`, `Require PostgresNIO 1.33.1` (earlier releases do not cancel a query against a silent server, which a cancelled transaction's rollback depends on). Never add a ceiling (`..<`) to work around an incompatibility; fix it or record it.

Depend on organization packages by tagged URL, never `.package(path:)` and never a branch. A path dependency builds only where the sibling happens to be checked out and can silently build against uncommitted changes. Publish and tag the dependency first, then raise the floor to the release containing what the library imports.

Declare traits explicitly where a dependency's defaults would pull in full Foundation: Hummingbird `traits: []`, swift-openapi-runtime `traits: []`, swift-configuration `traits: []` (see [foundation.md](../../writing-swift-server-code/references/foundation.md#dependency-traits-that-pull-in-foundation)). A library that genuinely requires an upstream full-Foundation product (PostgresNIO, Vapor 4) records it as a documented exception in its `AGENTS.md` CI profile.

Never commit `Package.resolved`: ignore it by name and resolve from the manifest. Applications commit theirs.

## Platforms

Server libraries declare `.macOS(.v15)` and build on Linux; that floor is what Swift Concurrency, `Mutex`, and the server dependencies require, and keeping it aligned lets any application link every package. A library meant for apps and SDKs as well as servers, such as swift-openapi-token-authentication, declares the Apple platforms it supports beside macOS. Linux CI does not establish Apple-platform compatibility; say what was verified.

## Versions, tags, and releases

- Libraries carry SemVer; applications do not. A release is a version tag cut by the repository's recorded mechanism: by default a tag plus a GitHub Release from the Auto Release workflow, computed from the labels of the pull requests merged since the last release; alternatively a bare version tag pushed by hand at the version those labels require, as a contract or SDK package may choose.
- Every pull request carries exactly one label: `⚠️ semver/major`, `🆕 semver/minor`, `🔨 semver/patch`, or `semver/none`. Auto Release, where used, refuses a major bump; a major is cut by hand.
- Before 1.0.0 a minor release is the breaking one, so the label names the version the change needs rather than its kind: removing a type, a product, or a target, or changing a signature or a documented behavior, is `🆕 semver/minor` in 0.x (`⚠️ semver/major` after 1.0.0); a compatible addition or a floor raise is `🔨 semver/patch` in 0.x (`🆕 semver/minor` after); README, `AGENTS.md`, tests, CI, formatting, and headers are `semver/none`. Doc comments and the DocC catalog ship in the package and the Swift Package Index publishes the latest release's documentation, so a correction there is `🔨 semver/patch`: Auto Release cuts nothing from `semver/none` alone, and a `semver/none` docs fix stays unpublished until something else releases. Record a break in the pull request and the release notes, and raise every consumer's floor deliberately.
- A tag is immutable once anything resolves it. SwiftPM records the commit a tag resolved to in `~/.swiftpm/security/fingerprints/`, and a moved tag fails every consumer's resolve until that file is deleted on every machine that saw the old one.
- Keep the README's install snippet at the latest release's floor when a release changes it; a README that pins a release older than the one that removed an API is documentation of the wrong package.

## Splitting and adding packages

When a library's dependency set grows a second technology, split it: the new technology becomes `swift-<concept>-<technology>` depending on the abstraction by tag, the abstraction loses the dependency, and both release. Removing a product or target is a breaking change; the removal and the replacement land in the same release.

A new driver for an existing abstraction follows the driver it resembles: `swift-persistence-<store>` exposes a `<Store>Database<Scope>` that opens the store's unit of work and hands the scope repositories a handle, proves commit and rollback against the real store in its own tests, and leaves the abstraction unchanged.
