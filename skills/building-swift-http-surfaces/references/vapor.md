# The Vapor alternative

## Contents

- [What changes](#what-changes)
- [The caller and the context](#the-caller-and-the-context)
- [Middleware](#middleware)
- [Controllers](#controllers)
- [Problem details](#problem-details)
- [Router](#router)
- [Tests](#tests)

A surface on Vapor 4 keeps every rule in [surface.md](surface.md) — one document, three tiers, administrative routes at the resource's path, one controller per resource, throwing conversions, problem details — in a gateway's `API` and a module's `<Module>HTTP` alike. A project chooses Vapor once, for every surface. Vapor links full Foundation; record it as the upstream full-Foundation requirement the [foundation reference](../../writing-swift-server-code/references/foundation.md) describes.

## What changes

| Hummingbird | Vapor 4 |
| --- | --- |
| `IdentityRequestContext`, `AdminRequestContext` | `req.auth`, an `AdministratorMiddleware` on a route group |
| `BearerAuthenticationMiddleware<IdentityRequestContext>` from AuthenticationHummingbird | `BearerAuthenticationMiddleware<UserIdentity>` from swift-authentication-vapor's `AuthenticationVapor` |
| `IsAuthenticatedMiddleware` | `UserIdentity.guardMiddleware()` |
| `UserSettingsMiddleware` binding a task-local | the Vapor `UserSettingsMiddleware`, writing `request.operationContext` |
| a controller with tier-named methods | a `RouteCollection` per resource |
| `ErrorMiddleware` and `HTTPProblemResponse` | a `ProblemMiddleware` and `AbortError` conformances |
| HummingbirdTesting `.router` | `VaporTesting` |

## The caller and the context

Two values, read from two places:

- **The identity** is `try req.auth.require(UserIdentity.self)`: the bearer middleware logs the verified identity in to `request.auth`, and `require` answers `401` when none is. Declare `extension UserIdentity: @retroactive Authenticatable {}` once in the surface's shared target (`<Project>HTTP`, or the single surface target); `UserIdentity` and `Authenticatable` both come from other modules.
- **The principal** — the identity with its token, which tenant settings and token propagation read — is in `request.operationContext`, the request-storage `OperationContext` AuthenticationVapor provides. Vapor 4 bridges its responder chain through event-loop futures, so a task-local bound in middleware does not reach a route; the bearer middleware therefore also writes the principal into `request.operationContext`.

A route that calls a use case whose transaction must carry the tenant, or an upstream that must carry the caller's token, runs that call under `OperationContext.withContext(req.operationContext)`, once, around the call.

## Middleware

The Vapor form of `UserSettingsMiddleware` lives in `<Project>Persistence` beside the Hummingbird one when the project uses Vapor. It reads the principal from `request.operationContext` and writes the tenant setting back into it:

```swift
import AuthenticationVapor
import OperationContext
import PersistencePostgres
import <Project>Authentication
public import Vapor

public struct UserSettingsMiddleware: AsyncMiddleware {
    public init() {}

    public func respond(to request: Request, chainingTo next: any AsyncResponder) async throws -> Response {
        if let user = request.operationContext.user {
            request.operationContext.postgresSettings = .user(user.identity)
        }
        return try await next.respond(to: request)
    }
}
```

The administrative gate is a route-group middleware, `401` when no caller is logged in and `403` when the role is not `.admin`; it reads only verified JWT role claims, and the use case still decides:

```swift
import <Project>Authentication
package import Vapor

package struct AdministratorMiddleware: AsyncMiddleware {
    package init() {}

    package func respond(to request: Request, chainingTo next: any AsyncResponder) async throws -> Response {
        let identity = try request.auth.require(UserIdentity.self)
        guard identity.role == .admin else {
            throw Abort(.forbidden, reason: "This operation requires an administrator.")
        }
        return try await next.respond(to: request)
    }
}
```

## Controllers

A controller is a `RouteCollection` holding the module's use-case protocols (or a gateway's generated client protocols), registered into the tier its routes need; a resource whose routes span tiers keeps tier-named registration methods over `any RoutesBuilder` instead of `boot(routes:)`. Conversions stay in `Schemas/Requests/` and `Schemas/Responses/` as `X+Schema.swift` (`X+RPC.swift` in a gateway), and typed use-case errors propagate to the problem middleware:

```swift
import NotesCore
import OperationContext
import <Project>Authentication
package import Vapor

package struct NoteController: RouteCollection {
    private let createNoteUseCase: any CreateNoteUseCaseProtocol
    private let listNotesUseCase: any ListNotesUseCaseProtocol

    package init(createNoteUseCase: any CreateNoteUseCaseProtocol, listNotesUseCase: any ListNotesUseCaseProtocol) {
        self.createNoteUseCase = createNoteUseCase
        self.listNotesUseCase = listNotesUseCase
    }

    package func boot(routes: any RoutesBuilder) throws {
        routes.post(use: createNote)
        routes.get(use: listNotes)
    }

    @Sendable
    private func createNote(_ req: Request) async throws -> Response {
        let subject = try req.auth.require(UserIdentity.self)
        let input = try CreateNoteUseCaseInput(try req.content.decode(Components.Schemas.CreateNoteRequest.self))
        let note = try await OperationContext.withContext(req.operationContext) {
            try await createNoteUseCase(subject: subject, input: input)
        }
        let response = Response(status: .created)
        try response.content.encode(Components.Schemas.NoteResponse(note), as: .json)
        return response
    }

    @Sendable
    private func listNotes(_ req: Request) async throws -> Response {
        let subject = try req.auth.require(UserIdentity.self)
        let notes = try await OperationContext.withContext(req.operationContext) {
            try await listNotesUseCase(subject: subject)
        }
        let response = Response(status: .ok)
        try response.content.encode(notes.map(Components.Schemas.NoteResponse.init), as: .json)
        return response
    }
}
```

The generated types are plain `Codable`, so encode and decode them through `req.content` with an explicit media type rather than conforming them to `Content`.

## Problem details

Conform each use case's typed error to Vapor's `AbortError` in the surface target, with the same statuses as on Hummingbird ([surface.md](surface.md#error-translation)):

```swift
import NotesCore
package import Vapor

extension CreateNoteUseCaseError: AbortError {
    package var status: HTTPResponseStatus {
        switch self {
        case .invalidBody: .badRequest
        case .forbidden: .forbidden
        case .unknown: .internalServerError
        }
    }

    package var reason: String { status.reasonPhrase }
}
```

Replace Vapor's default `ErrorMiddleware` with one that answers every failure as problem details and logs server errors with their cause:

```swift
package import Vapor

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

package struct ProblemMiddleware: AsyncMiddleware {
    package init() {}

    package func respond(to request: Request, chainingTo next: any AsyncResponder) async throws -> Response {
        do {
            return try await next.respond(to: request)
        } catch {
            let abort = error as? any AbortError
            let status = abort?.status ?? .internalServerError
            if status.code >= 500 {
                request.logger.error("Request failed", metadata: ["error": "\(String(reflecting: error))"])
            }
            let problem = Problem(
                type: "about:blank",
                title: status.reasonPhrase,
                status: Int(status.code),
                detail: status.code >= 500 ? nil : abort?.reason,
                instance: request.url.path
            )
            var headers = HTTPHeaders()
            headers.contentType = HTTPMediaType(type: "application", subType: "problem+json")
            return Response(status: status, headers: headers, body: .init(data: try JSONEncoder().encode(problem)))
        }
    }
}
```

`Problem` is the same hand-written `Encodable` struct as on Hummingbird, without the Hummingbird response helper. Encode it directly: Vapor's content configuration registers no encoder for `application/problem+json`.

## Router

The tiers are route groups, registered in the root's Router section. Reset the application's middleware so the problem middleware is first:

```swift
// MARK: - Router
app.middleware = Middlewares()
app.middleware.use(RouteLoggingMiddleware(logLevel: .info))
app.middleware.use(ProblemMiddleware())

let v1 = app.grouped("v1")

// Tier 1: no caller.
v1.get("health") { _ in HTTPStatus.ok }
try v1.grouped("auth").register(collection: sessionController)

// Tier 2: a caller if there is one.
let identified = v1.grouped(
    BearerAuthenticationMiddleware<UserIdentity>(authenticator: userAuthenticator),
    UserSettingsMiddleware()
)

// Tier 3: a caller is required.
let authenticated = identified.grouped(UserIdentity.guardMiddleware())
try authenticated.grouped("notes").register(collection: noteController)

// Administrative routes at the resource's path.
let administrative = authenticated.grouped(AdministratorMiddleware())
try administrative.grouped("users").register(collection: userAdministrationController)
```

Unlike Hummingbird's `add(middleware:)`, `grouped(_:)` returns a new builder, so each tier is its own group. The listener comes from the same `http.server` configuration scope, and the `Vapor.Application` runs in the root's `ServiceGroup`. A client-facing listener serves TLS with the process's leaf and requires no client certificate, as in [surface.md](surface.md#composition); the configuration NIOCertificateReloading builds carries the root's primed reloader, so renewed leaves apply on new handshakes without a restart:

```swift
app.http.server.configuration.tlsConfiguration = try .makeServerConfiguration(certificateReloader: certificateReloader)
```

## Tests

Compose the application as the root does, over mocked use-case protocols and a real `JWTIssuer<UserIdentity>` and `JWTAuthenticator<UserIdentity>` over a throwaway key, and drive it with `VaporTesting`. Keep the root's Router section in a function the test target can call, or mirror it exactly:

```swift
import Testing
import Vapor
import VaporTesting

@Test("an anonymous caller cannot list notes")
func anonymousListIsRefused() async throws {
    let tokens = try await TestTokens.make()
    let app = try await Application.make(.testing)
    do {
        try addRoutes(
            to: app,
            userAuthenticator: tokens.authenticator,
            noteController: NoteController(createNoteUseCase: MockCreateNoteUseCase(), listNotesUseCase: MockListNotesUseCase())
        )
        try await app.testing().test(.GET, "v1/notes") { response async in
            #expect(response.status == .unauthorized)
            #expect(response.headers.contentType == HTTPMediaType(type: "application", subType: "problem+json"))
        }
    } catch {
        try await app.asyncShutdown()
        throw error
    }
    try await app.asyncShutdown()
}
```

The tier matrix, conversions, and distinct error mappings to cover are the same as on Hummingbird ([surface.md](surface.md#tests)).
