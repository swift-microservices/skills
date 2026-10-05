# The organization layer

## Contents

- What `<project>-core` holds
- `<Project>Authentication`
- `<Project>Persistence`
- `<Project>Testing`
- What stays out
- `<project>-protos`

The swift-microservices packages know nothing of an organization. `<project>-core` is the one library where an organization decides, once, what every one of its services shares: the user's claims, the roles, the setting the tenant policies read, the interceptor and middleware that bind it, and the test doubles. It is a library like any other here — Swift settings, formatter, headers, swift-testing, SemVer labels, tagged releases, no `Package.resolved` — with the organization's license and owner (a proprietary project uses `SPDX-License-Identifier: LicenseRef-Proprietary`).

## What `<project>-core` holds

| Product | Holds | Linked by |
| --- | --- | --- |
| `<Project>Authentication` | `UserIdentity` (the JWT payload), `UserRole`, `ServiceContext.user`, the `.user` logging metadata provider, and the EdDSA `JWTIssuer`/`JWTAuthenticator` initializers | every Core, transport target, and executable |
| `<Project>Persistence` | `PostgresSettings.user(_:)`, `UserSettingsInterceptor`, `UserSettingsMiddleware` | the executable of a process with a database and tenant tables |
| `<Project>Testing` | `MockDatabase<Scope>`, `MockUserAuthenticator` | test targets only |

Each product is its own dependency set, so a domain target that links `<Project>Authentication` acquires no transport: the gRPC and Hummingbird dependencies sit in `<Project>Persistence`, which only an executable links.

## `<Project>Authentication`

`UserIdentity` is the organization's `JWTPayload`: `sub` is the user's UUID (`userId`), plus `role`, `iss`, `iat`, `exp`, and an audience when the deployment uses one. Its `verify(using:)` enforces the claims the deployment depends on, expiry at least; no business state, entitlements, or secrets ride in the token. `UserRole` is an open string with `.user` and `.admin` constants, so an unknown role is never read as an administrator.

```swift
extension ServiceContext {
    /// The verified user bound by the bearer interceptor or middleware.
    public var user: Principal<UserIdentity, String>? {
        get { self[PrincipalKey<UserIdentity, String>.self] }
        set { self[PrincipalKey<UserIdentity, String>.self] = newValue }
    }
}

extension Logger.MetadataProvider {
    /// Adds `user_id` to every log line inside a request with a verified user.
    public static let user = Logger.MetadataProvider { /* reads ServiceContext.current?.user */ }
}

extension JWTAuthenticator where Payload == UserIdentity {
    /// The authenticator of user tokens, over the EdDSA public key every service holds.
    public init(publicKey: EdDSA.PublicKey) async {
        let keys = JWTKeyCollection()
        await keys.add(eddsa: publicKey)
        self.init(keys: keys)
    }
}
// JWTIssuer gains init(privateKey:) the same way; only the authenticating service calls it.
```

Loading key files and reading configuration stay in each executable; the conveniences take key values, not paths.

## `<Project>Persistence`

`PostgresSettings.user(_:)` turns a verified user into the one setting the tenant policies read, `app.caller_user_id`, lowercased. `UserSettingsInterceptor` (a GRPCCore `ServerInterceptor`) and `UserSettingsMiddleware<Context: RequestContext>` (a Hummingbird `RouterMiddleware`) read `ServiceContext.current?.user`, and when a user is bound run the continuation under a `ServiceContext` carrying `postgresSettings = .user(user.identity)`; with no user they continue unchanged, which the policies treat as no rows. Both follow the bearer binding: the interceptor on every `<Entity>Service` descriptor and never an internal one, the middleware in the identifying tier; and both match their framework's `@concurrent` continuation requirement. A project on Vapor adds the Vapor form, which reads and writes `request.serviceContext`. Where the tenant is an organization rather than a user, the setting and the helper name that id instead.

## `<Project>Testing`

`MockDatabase<Scope>` conforms to `Database` with no transaction and a fixed scope: `withTransaction` hands every unit of work the same scope, caller-isolated like the real one. `MockUserAuthenticator` is an `Authenticator<String, UserIdentity>` over a table (`MockUserAuthenticator(["admin-token": admin])`) that throws for an unknown token. These are the only doubles every service would write identically; mock repositories and scopes stay in each service.

## What stays out

- Configuration readers, transport-security factories, certificate reloaders, composition, and logging bootstrap: each executable owns them, because they diverge between processes.
- Repositories, scopes, migrations, and business authorization: the owning service's.
- Proto contracts: `<project>-protos`.
- Generic authentication or persistence abstractions: upstream, in the swift-microservices packages.
- A process identity or service token: processes are proved by their certificates over mTLS.

## `<project>-protos`

The canonical proto package is a library too: one `<Module>Protos` product per module with a gRPC contract, generated with the `GRPCProtobufGenerator` plugin at `public` access, versioned additively, released by tag before any producer or consumer pins it. Its layout and generator configuration are in the building skill's [gRPC reference](../../building-swift-services/references/grpc-and-protos.md#canonical-proto-package). It has no runtime tests, so its CI is the library profile's build-and-consumer variant for generated packages.
