# The organization core: persistence

Every source file of `<Project>Persistence`, and its Vapor form. The layout, the manifest, `<Project>Testing`, and the required tests are in [organization-core-code.md](organization-core-code.md).

## Contents

- [`<Project>Persistence`](#projectpersistence)
- [The Vapor form](#the-vapor-form)

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
