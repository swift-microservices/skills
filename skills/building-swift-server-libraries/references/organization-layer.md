# The organization layer

## Contents

- [When it is a package](#when-it-is-a-package)
- [What `<project>-core` holds](#what-project-core-holds)
- [Product exceptions](#product-exceptions)
- [`<Project>Authentication`](#projectauthentication)
- [`<Project>Persistence`](#projectpersistence)
- [`<Project>Testing`](#projecttesting)
- [Tests](#tests)
- [What stays out](#what-stays-out)
- [`<project>-protos`](#project-protos)
- [Private repositories](#private-repositories)

The swift-microservices packages know nothing of an organization. The organization layer is where an organization decides, once, what every one of its processes shares: the user's claims, the roles, the setting the tenant policies read, the interceptor and middleware that bind it, and the test doubles. As a package it is a library like any other here — Swift settings, formatter, headers, swift-testing, SemVer labels, tagged releases, no `Package.resolved` — with the organization's license and owner (a proprietary project uses `SPDX-License-Identifier: LicenseRef-Proprietary`). The complete code is in [organization-core-code.md](organization-core-code.md).

## When it is a package

A one-package modular monolith keeps `<Project>Authentication`, `<Project>Persistence`, and `<Project>Testing` as targets in its own package, with the same names, files, and dependency sets. The day a second package needs them (a service split out, a gateway, a worker in its own repository), they move unchanged to a tagged `<project>-core` repository, and every package, the monolith included, depends on it by tag. Contracts follow the same rule into `<project>-protos`.

## What `<project>-core` holds

| Product | Holds | Linked by |
| --- | --- | --- |
| `<Project>Authentication` | `UserIdentity` (the JWT payload), `UserRole`, `OperationContext.user`, the `.user` logging metadata provider, and the EdDSA `JWTIssuer`/`JWTAuthenticator` initializers | every Core, transport target, and executable |
| `<Project>Persistence` | `PostgresSettings.user(_:)`, `UserSettingsInterceptor`, `UserSettingsMiddleware` | the executable of a process with a database and tenant tables |
| `<Project>Testing` | `MockDatabase<Scope>`, `MockUserAuthenticator` | test targets only |

Each product is its own dependency set, so a domain target that links `<Project>Authentication` acquires no transport.

## Product exceptions

This is the one place the exceptions to one product per package and one technology per product are recorded:

- **`<project>-core` has three products**, one per dependency set above, so a Core target never links what only an executable or a test needs.
- **`<Project>Persistence` bundles transports.** Its gRPC and Hummingbird bindings (the Vapor one on a Vapor project) share one product because only executables link it, and an executable already links the transport it serves.
- **`<Project>Testing` is a test-support product**, linked by test targets only, because every service would otherwise write those doubles identically. A swift-microservices library keeps its doubles inside its test target.
- **`<project>-protos` has one `<Module>Protos` product per contract.** The products share their dependencies; a consumer imports only the contracts it calls.

## `<Project>Authentication`

`UserIdentity` is the organization's `JWTPayload`: `sub` decodes into the user's UUID (`userId`), `iss`, `iat`, and `exp` into `issuer`, `issueDate`, and `expirationDate`, plus `role` and an audience when the deployment uses one. Its `verify(using:)` enforces the claims the deployment depends on, expiry at least; no business state, entitlements, or secrets ride in the token. `UserRole` is an open string with `.user` and `.admin` constants, so an unknown role is never read as an administrator. `OperationContext.user` is a named accessor over swift-authentication's `PrincipalKey<UserIdentity, String>`, which the bearer bindings set; the `.user` metadata provider adds only `user_id`, nothing without a user, and never the credential. The EdDSA conveniences take key values; loading key files and reading configuration stay in each executable.

## `<Project>Persistence`

`PostgresSettings.user(_:)` turns a verified user into the one setting the tenant policies read, `app.caller_user_id`, lowercased. `UserSettingsInterceptor` (GRPCCore) and `UserSettingsMiddleware<Context>` (Hummingbird) copy `OperationContext.current`, and when a user is bound run the continuation under that copy with `postgresSettings = .user(user.identity)`; with no user they continue unchanged, which the policies treat as no rows. Both follow the bearer binding: the interceptor on every `<Entity>Service` descriptor whose module has tenant tables and never an internal one, the middleware in the identifying tier; both match their framework's `@concurrent` continuation exactly. The Vapor form reads and writes `request.operationContext`, and the `UserIdentity: Authenticatable` conformance Vapor's bearer middleware needs lives in the HTTP target, not here. Where the tenant is an organization rather than a user, the setting and the helper name that id instead.

## `<Project>Testing`

`MockDatabase<Scope>` conforms to `Database` with no transaction and a fixed scope: `withTransaction` hands every unit of work the same scope, caller-isolated like the real one. `MockUserAuthenticator` is an `Authenticator<String, UserIdentity>` over a table (`MockUserAuthenticator(["admin-token": admin])`) that throws `UnknownToken(token:)` for any other token. These are the only doubles every service would write identically; mock repositories and scopes stay in each service.

## Tests

One `<Project>CoreTests` target covers all three modules; an mTLS contract suite, where the core documents mTLS composition, is a separately named target so ordinary tests do not acquire its dependencies. The required tests — the exact wire claim set, the EdDSA round trip, an expired token, a non-UUID `sub`, metadata scoping, the interceptor and the middleware on both branches with the enclosing context restored, and the mocks' isolation — are listed in [organization-core-code.md](organization-core-code.md#tests).

## What stays out

- Configuration readers, transport-security factories, certificate reloaders, composition, and logging bootstrap: each executable owns them, because they diverge between processes.
- Repositories, scopes, migrations, and business authorization: the owning service's.
- Proto contracts: `<project>-protos`.
- Generic authentication or persistence abstractions: upstream, in the swift-microservices packages.
- A process identity or service token: processes are proved by their certificates over mTLS.

## `<project>-protos`

The canonical proto package is a library too, released by tag before any producer or consumer pins it and versioned additively. The proto file layout, package names, and versioning rules are the building skill's [canonical proto package](../../building-swift-services/references/grpc-and-protos.md#canonical-proto-package); this section is the package around them.

**Products are `<Module>Protos`**, without the `<Project>` prefix other organization-layer products carry: the generated types already carry the proto package as a prefix (`<Organization>_<Module>_V1_`), and the product names the contract a consumer imports. One target per contract:

```swift
.target(
    name: "UsersProtos",
    dependencies: [
        .product(name: "GRPCCore", package: "grpc-swift-2"),
        .product(name: "GRPCProtobuf", package: "grpc-swift-protobuf"),
        .product(name: "SwiftProtobuf", package: "swift-protobuf"),
    ],
    swiftSettings: swiftSettings,
    plugins: [
        .plugin(name: "GRPCProtobufGenerator", package: "grpc-swift-protobuf")
    ]
),
```

**Generator configuration.** Every target carries the same `grpc-swift-proto-generator-config.json`. `accessLevelOnImports` is required: the plugin defaults it to `false`, and under `InternalImportsByDefault` the generated plain imports are internal, so public generated types fail to compile against them.

```json
{
  "generate": {
    "clients": true,
    "servers": true,
    "messages": true
  },
  "generatedSource": {
    "accessLevel": "public",
    "accessLevelOnImports": true
  }
}
```

**Marker file.** `Sources/<Module>Protos/<Module>Protos.swift` holds only the license header: a target needs one Swift source for SwiftPM to build it, and the plugin's output is generated at build time, never tracked or edited.

**DocC.** Each target has `Documentation.docc/<Module>Protos.md`: one sentence naming the proto package, an overview of who serves it and who calls it, and topics grouped by audience — the `<Entity>Service` RPCs people reach through the gateway, and the `<Entity>InternalService` other processes call over mTLS:

```markdown
# ``UsersProtos``

The `<organization>.users.v1` contract: messages, clients, and servers generated from `users.proto`.

## Overview

The users service serves it; the gateway and the authentication service call it.

## Topics

### People, through the gateway

- ``<Organization>_Users_V1_UserService``

### Other processes

- ``<Organization>_Users_V1_UserInternalService``
```

**Consumer fixture.** A generated package has no runtime tests, so `.github/Fixtures/Consumer` is a separate package, `.package(path: "../../..")`, with the shared settings, linking every `<Module>Protos` product and declaring `public typealias`es of generated messages, `ClientProtocol`s, and `ServiceProtocol`s from `public import`s; a contract whose generated API is not public, or whose imports are not, fails to build there. `.gitignore` ignores `.github/Fixtures/**/.build/` and every `Package.resolved`. CI is the library profile's build-and-consumer variant for generated packages.

**Wire enums are not token roles.** A contract's `UserRole` enum (`USER_ROLE_UNSPECIFIED`, `USER_ROLE_USER`, `USER_ROLE_ADMIN`) is what the owning service persists and returns; the token's `UserRole` in `<Project>Authentication` is an open string. Map them at the transport boundary and refuse `UNSPECIFIED`. Adding a role changes `<project>-core` first, then the contract, then the issuing service.

## Private repositories

`<project>-core` and `<project>-protos` are often private. A private repository has no `.spi.yml` and no Swift Package Index badge, since the index cannot build it; its DocC catalogs still build in CI's docs check. Every consumer resolves its tags with credentials, in CI and in image builds alike (see the delivering skill's [library CI profile](../../delivering-swift-services/references/library-ci.md)), and the repository's `AGENTS.md` records both as profile exceptions.
