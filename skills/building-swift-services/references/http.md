# The HTTP surface

How HTTP is put on the system: the target that owns it, the OpenAPI document, the request contexts, the router tiers, the middleware that identifies a caller and binds the tenant, the controllers, the conversions, and the error translation. The same surface serves two shapes with one set of rules; only the controller's collaborator differs:

- **A monolith's HTTP transport.** Each module has an `<Module>HTTP` target whose controllers call the module's use-case protocols directly, and the one executable mounts every module's controllers on one router.
- **A gateway in front of services.** A package of its own, `<organization>-api`, whose controllers call generated gRPC client protocols and forward the caller's token to the user-facing upstreams.

Hummingbird is the default framework; the Vapor section at the end covers what changes on Vapor 4.

## Contents

- Where HTTP lives
- The gateway package
- The OpenAPI document is the contract
- Request contexts
- Router tiers
- The tenant on HTTP
- Route design
- Controllers
- Schema conversion
- Idempotency keys the client does not carry
- Error translation
- Composition
- One surface or two
- Deployment
- The Vapor alternative
- Tests

## Where HTTP lives

HTTP is a transport target like gRPC is, one per module, in both shapes:

```text
<organization>-backend                       # a monolith, HTTP-only
├── CatalogCore, CatalogPostgres, CatalogHTTP
├── UsersCore, UsersPostgres, UsersHTTP
└── Backend ──→ every module's targets        # one router, one application

<organization>-catalog                       # a service exposing HTTP beside or instead of gRPC
├── CatalogCore, CatalogPostgres, CatalogHTTP, CatalogGRPC
└── Catalog
```

An `<Module>HTTP` target owns that module's request contexts only if it declares any of its own, its controllers, its schema conversions, and its route registration. It links `Hummingbird`, `HummingbirdAuth`, `Authentication`, and `<Project>Authentication`, and its own module's Core; never Postgres, never another module's targets. The types a module's surface shares with every other module's — the contexts, the error middleware, the problem types, the OpenAPI-generated types when the document is one — live in a `<Project>HTTP` target the module targets link, so the surface has one vocabulary. A monolith with one module, or a service, folds `<Project>HTTP` into its single `<Module>HTTP`.

Controllers over use cases hold use-case protocol existentials, exactly as a gRPC producer adapter does, and call them with `subject:` or `input:` from the context:

```swift
package struct ItemController: Sendable {
    private let createItemUseCase: any CreateItemUseCaseProtocol
    private let listItemsUseCase: any ListItemsUseCaseProtocol

    package func addPublicRoutes(to group: RouterGroup<BasicRequestContext>) { ... }        // input:
    package func addAuthenticatedRoutes(to group: RouterGroup<IdentityRequestContext>) { ... }  // subject:input:
}
```

The transport target is what keeps a module movable. When a module becomes a service, its `<Module>HTTP` target moves into the new package unchanged, and the old executable's controllers for it become gateway controllers over the new service's client protocols — the same routes, the same conversions, a different collaborator.

## The gateway package

When the modules are services, the HTTP surface is its own process. Name the package `<organization>-api`, not `-gateway`: the naming grammar refuses `gateway` as a type name, and the thing that actually gateways — routing, TLS termination, rate limiting — is the ingress in front of this process. What this package holds is hand-written controllers mapping one contract onto another, which is an edge service.

```text
<organization>-api
├── API ────────→ generated OpenAPI types, contexts, middleware, controllers, conversions
└── <Project> ──→ API   # command tree, configuration, clients, lifecycle
```

Two targets, not four. A gateway owns no entities, no repositories, and no database, so `Core` and `Postgres` targets would be empty. Do not add an `APICore` to mirror the service shape: the only candidates for it are the request contexts and the problem types, and both are transport concerns that belong beside the controllers that use them.

| Target | Owns | Must not own |
| --- | --- | --- |
| `API` | Generated OpenAPI types, request contexts, error middleware and problem types, controllers, RPC conversions, route registration | Environment reading, client construction, logging setup, `@main` |
| `<Project>` | ArgumentParser command tree, configuration, client and authenticator construction, router assembly, lifecycle — the target that builds the `JWTAuthenticator` from the key | Route handlers, schema conversion, business rules |

`API` links `Hummingbird`, `HummingbirdAuth`, `Authentication`, `AuthenticationHummingbird`, and `<Project>Authentication`; the executable adds `AuthenticationJWT`, `AuthenticationGRPC`, `JWTKit`, the gRPC transport, and one `<Service>Protos` product per upstream. The gateway never speaks an internal service: it relays people, and a process is what an internal service admits.

The exact source tree:

```text
Sources/
├── API/
│   ├── openapi.yaml
│   ├── openapi-generator-config.yaml
│   ├── <Project>API.swift
│   ├── Contexts/
│   │   ├── IdentityRequestContext.swift
│   │   └── AdminRequestContext.swift
│   ├── Controllers/
│   │   ├── AuthenticationController.swift
│   │   ├── ItemController.swift
│   │   └── ProfileController.swift
│   ├── Middlewares/
│   │   └── ErrorMiddleware/
│   │       ├── ErrorMiddleware.swift
│   │       └── Problem/
│   │           ├── Problem.swift
│   │           ├── HTTPProblemResponse.swift
│   │           └── Conformances/
│   │               ├── HTTPError+HTTPProblemResponse.swift
│   │               └── RPCError+HTTPProblemResponse.swift
│   └── Schemas/
│       ├── Requests/
│       │   └── CreateItemRequest+RPC.swift
│       └── Responses/
│           └── ItemResponse+RPC.swift
└── <Project>/
    ├── <Project>.swift
    ├── Serve/
    │   └── Serve.swift
    └── Configuration/
        ├── EdDSA.PublicKey+ConfigReader.swift
        └── TransportSecurity+ConfigReader.swift
```

A monolith's `<Module>HTTP` target keeps the same folders — `Controllers/`, `Schemas/Requests/`, `Schemas/Responses/` — under its own module, with the conversions named `X+Schema.swift`, and no `RPCError` conformance.

## The OpenAPI document is the contract

Keep `openapi.yaml` in the generating target's directory beside `openapi-generator-config.yaml`. That is where the generator plugin looks. Do not keep it elsewhere and reach for it with `resources: [.copy("../../Docs/openapi.yaml")]`: the relative path escapes the target directory, which SwiftPM warns about, and the copy exists only to satisfy a lookup the convention already performs.

Generate types only:

```yaml
generate:
  - types
accessModifier: package
```

Routes are registered by hand on Hummingbird, so generated server stubs would be a second routing mechanism maintained for the same endpoints. Use `package`, not `public` — the types cross target boundaries inside one package.

One document per surface. A monolith has one, in `<Project>HTTP`, describing every module's routes; a gateway has one in `API`. Two documents produce two unrelated Swift types for every schema they share. Unimplemented paths in the document cost nothing while types are all that is generated, so the document can lead the implementation and serve as the checklist.

## Request contexts

Chain three, each narrowing what the handler is allowed to assume:

```swift
package struct IdentityRequestContext: ChildRequestContext, AuthRequestContext {
    package typealias ParentContext = BasicRequestContext

    package var coreContext: CoreRequestContextStorage
    package var identity: UserIdentity?

    package init(context: BasicRequestContext) throws {
        self.coreContext = context.coreContext
        self.identity = nil
    }
}
```

Carry `coreContext` across. Do not rebuild it with `.init(source: context)`, which is what Hummingbird's own `ChildRequestContext` documentation shows: `CoreRequestContextStorage`'s `init(source:)` starts `parameters` and `endpointPath` empty, and path parameters are extracted before the child is constructed. Rebuilding silently discards them, so a route declared with `:id` matches, runs, and then cannot find its own parameter.

The admin context holds a non-optional identity, because reaching a handler through it is the proof the check ran:

```swift
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
```

Distinguish the two failures for the same reason gRPC handlers do. Absent is `401`, because presenting a token could change the answer; insufficient is `403`, because it could not.

The surface is for people, and every token is a person's: a process proves who it is with its certificate and never reaches an HTTP surface with a token, and a token whose subject is not a user id fails to decode as a `UserIdentity` before any handler sees it. Give `IdentityRequestContext` a `requireUser()` all the same, and use it on every route that acts on "the caller's own" account — it is `requireIdentity()` under the name the routes use for what they mean, and the name records the intent:

```swift
package func requireUser() throws -> UserIdentity {
    try requireIdentity()
}

extension UserIdentity {
    /// The user id as the contracts spell it: lowercased, the way Postgres prints one.
    package var subject: String { userId.uuidString.lowercased() }
}
```

In a monolith the admin context is not the authorization: the use case still checks `.admin` in its own body and throws its own `.forbidden`, and the context is what keeps an administrative handler from being reachable without a caller at all. The check exists twice only in the sense that the transport refuses early what the use case would refuse anyway; the use case's copy is the one the tests cover.

## Router tiers

Register routes in three tiers, and let the tier — not a path prefix or a path exception — decide what runs:

```swift
let router = Router(context: BasicRequestContext.self)
router.add(middleware: CORSMiddleware(...))
router.add(middleware: ErrorMiddleware())
router.add(middleware: LogRequestsMiddleware(.info))

let v1 = router.group("v1")

// Tier 1 — no caller. Session-issuing routes and the health route.
authenticationController.addPublicRoutes(to: v1.group("auth"))

// Tier 2 — a caller if there is one; anonymous requests still arrive.
let identified = v1.group(context: IdentityRequestContext.self)
    .add(middleware: BearerAuthenticationMiddleware<IdentityRequestContext>(authenticator: userAuthenticator))
    .add(middleware: UserSettingsMiddleware<IdentityRequestContext>())

// Tier 3 — a caller is required.
let authenticated = identified.add(middleware: IsAuthenticatedMiddleware())
```

`BearerAuthenticationMiddleware` comes from swift-authentication-hummingbird's `AuthenticationHummingbird`; it takes any `Authenticator<String, UserIdentity>`, sets the context's `identity`, and binds the `Principal<UserIdentity, String>` in `ServiceContext` that the tenant middleware and the propagating interceptor read. The `<Module>HTTP` or `API` target links `Authentication` to name the authenticator protocol and `<Project>Authentication` for `UserIdentity`; the key, and `AuthenticationJWT`, reach only the executable.

Tier 1 exists for the same reason the session-issuing RPCs live on a public service with no interceptor: it is that rule, one transport over. Token refresh sends the refresh token in the `Authorization` header, and a refresh token is a database row rather than a signed one. An authenticating middleware applied to it verifies that value as a claim payload, fails, and returns `401` before the handler is reached — so the route cannot succeed at any point, for any client. Grouping by tier prevents that structurally. A path exception inside the middleware does not: it restates the rule in a second place that drifts.

Tier 2 is where a route that reads differently for a known caller belongs — a catalogue that is public but richer once logged in. Do not collapse tiers 2 and 3; identifying and requiring are separate decisions here exactly as they are on gRPC.

## The tenant on HTTP

On gRPC the bound user becomes the tenant setting through `UserSettingsInterceptor`; on HTTP the same job is `UserSettingsMiddleware`, its HTTP counterpart in `<Project>Persistence`, added to the identifying tier right after the bearer middleware. It reads `ServiceContext.current?.user`, and when a user is bound runs the rest of the request under a `ServiceContext` carrying `PostgresSettings.user(_:)` — the one setting, `app.caller_user_id` — so every transaction a use case begins during the request applies it and the tenant policy sees the caller. With no user bound it binds nothing, and a policy then admits no rows.

A gateway has no database and no tenant middleware: the setting is applied where the transaction runs, by the service the token is forwarded to. A monolith or an HTTP-serving service with a tenant table applies it here, and the monolith is the place to notice that the token is verified exactly once — at this middleware — because no process boundary is crossed between it and the tables.

## Route design

Authorization is a property of the method-and-resource pair, not of a path prefix. A parallel `/admin/...` tree makes `/admin/users` and `/users` two resources when they are one resource with two audiences, and it splits the document into two shapes for the same thing.

Flatten it, and let three mechanisms carry the distinction:

- **Method.** Reads open, writes admin: `GET /items` alongside `POST /items`.
- **Collection versus item.** `GET /users` is inherently an administrative capability where `GET /profile` is not.
- **Sub-resources.** `/users/{id}/orders` for an administrator, a caller-scoped route for everyone else.

Express the administrative half as a context group at the same path, never a path group:

```swift
package func addAuthenticatedRoutes(to group: RouterGroup<IdentityRequestContext>) {
    group
        .group(context: AdminRequestContext.self)
        .get(use: listUsers)
        .get(":id", use: getUser)
}
```

The conversion throws, so an administrative handler is unreachable without the check having run, and the guarantee is in the type rather than in the order middleware happened to be added.

Two limits, both worth respecting rather than forcing through:

- Flattening fails where two operations share a method and path but differ in scope — a caller-scoped list and an administrative list of everything. Keep those distinct with a query parameter or a separate path; collapsing them produces one operation with two meanings.
- Not every route is a resource. Sessions, provider webhooks, and checkout callbacks are workflows, and `POST /payments/<provider>/webhook` is the honest spelling. Do not restructure a working verb-shaped route to satisfy a taxonomy.

Where a check depends on a path parameter — this record if it is yours, any record if you are an administrator — it cannot be a context. In a monolith it is the use case's guard, as always. In a gateway, where no use case runs, write it in the handler and give it one name rather than open-coding it at each call site.

## Controllers

One `XController` per resource, holding protocols rather than concrete types so a test can substitute them. What the protocol is depends on the shape:

- Over use cases, in a module's own surface: the use-case protocol existentials the module's Core declares, one per operation the resource exposes. The controller reads the caller from the context and passes it as `subject:`; a public route passes `input:` alone.
- Over services, in a gateway: generated client protocols, one per proto service the resource speaks, because a proto service is one audience and a public route must not reach a user RPC through the wrong stub:

```swift
package struct ItemController: Sendable {
    private let publicClient: <Organization>_Catalog_V1_ItemPublicService.ClientProtocol
    private let client: <Organization>_Catalog_V1_ItemService.ClientProtocol

    package func addPublicRoutes(to group: RouterGroup<BasicRequestContext>) { ... }        // publicClient
    package func addAuthenticatedRoutes(to group: RouterGroup<IdentityRequestContext>) { ... }  // client
}
```

Name the registration methods for the tier they mount into. A gateway controller may reach more than one service — an item's record is owned by catalog while its stock level is owned by inventory — and that is the gateway working: which service answers a resource is its problem, not the client's. A module controller reaches its own module's use cases only; a route that needs another module's answer goes through the use case, which holds the other module's protocol, never through a second controller collaborator.

Keep the path prefix in the composition root and the routes in the controller, so one file shows the whole surface and each controller stays movable.

## Schema conversion

Put conversions in `Schemas/Requests/` and `Schemas/Responses/`. In a gateway they are `X+RPC.swift` and convert between the generated OpenAPI types and protobuf messages, matching the producer-side `Protobuf/` convention. In a module's surface they are `X+Schema.swift` and convert between the generated OpenAPI types and Core's inputs and entities, exactly as `X+Protobuf.swift` does for gRPC; transport validation — UUID parsing, ranges, enum recognition — happens in that initializer, and generated schema types never reach Core.

Make a conversion throw rather than drop:

```swift
extension Components.Schemas.ItemResponse: ResponseCodable {
    init(_ item: <Organization>_Catalog_V1_Item) throws {
        guard let id = UUID(uuidString: item.id) else {
            throw HTTPError(.internalServerError, message: "The item record is malformed.")
        }
        self.init(id: id, name: item.name)
    }
}
```

A `compactMap` over a malformed field returns a shorter list and a `200`, so a client sees a record that has disappeared rather than an error anybody investigates. A value the upstream should never have produced is a fault in that upstream and should say so.

## Idempotency keys the client does not carry

A create may take an idempotency key (see *Idempotent writes* in [persistence.md](persistence.md)) that the HTTP client has no natural way to supply — an administrator creating a catalogue row does not hold a stable operation id. Keep the key out of the OpenAPI request and mint one in the conversion, so the HTTP surface stays clean while the create contract and its own unique constraints still hold. This is not the same as idempotency: a fresh key per request means each HTTP call is a new logical attempt, and true de-duplication rests on the resource's unique column (a provider's price id, an email). Expose the key at HTTP only when the client genuinely retries a specific operation and can carry the same key across attempts.

## Error translation

Answer every failure as RFC 9457 problem details with `application/problem+json`.

In a module's surface, map the use case's typed errors the way the gRPC producer adapter does, in the handler, explicitly: invalid input `400`, not found `404`, a duplicate `409`, the use case's `.forbidden` `403`, an absent caller `401` from the context, and `.unknown` `500` logged with its cause. A handler translates one use-case error enum; it never sees `PSQLError` or a repository error, which persistence and Core already classified.

In a gateway, map `RPCError` by code rather than collapsing it:

| gRPC code | HTTP |
| --- | --- |
| `invalidArgument`, `failedPrecondition`, `outOfRange` | 400 |
| `unauthenticated` | 401 |
| `permissionDenied` | 403 |
| `notFound` | 404 |
| `alreadyExists`, `aborted` | 409 |
| `resourceExhausted` | 429 |
| `unimplemented` | 501 |
| `unavailable` | 503 |
| `deadlineExceeded` | 504 |

The producing service already classified the failure into a status the contract defines. Mapping every RPC failure to `500` discards that work at the last hop and tells a client to retry what cannot succeed. Reserve `500` for a failure the surface itself could not classify, and log that one with the underlying error.

## Composition

The composition root — a monolith mounting every module's controllers, a service's serve command adding HTTP beside gRPC, a gateway building its clients — is in [composition.md](composition.md), under *HTTP composition* and *Gateway composition root*; the section order is Configuration, Logging, Infrastructure, Composition, Router, Hummingbird, Lifecycle. Two rules belong here because they shape the surface:

- Every upstream a gateway dials is one connection and two audiences, so the caller's token is resent only on the proto service that takes one, through `BearerPropagationInterceptor<UserIdentity>` applied per user-service descriptor; the public stub is dialled with nothing, which is what the session-issuing RPCs expect.
- Read the listener from configuration with `ApplicationConfiguration(reader:)`, scoped to `http.server`, and own the application and every client in one `ServiceGroup`.

## One surface or two

Default to one target, one document, and one application. Authorization by context conversion is enough to keep administrative routes out of ordinary hands, and a second surface doubles the generated type set.

Split into two Hummingbird applications — two routers, two ports, one `ServiceGroup` — only when the administrative routes must not be publicly routable at all. That buys something a role check cannot: the routes are absent from the public router's tree, so no ordering mistake can expose them, and the port is simply never published.

Before splitting, check whether the administrative client removes the need. A browser client served by its own process can proxy same-origin to an unpublished port, which gets the isolation without splitting Swift targets, and leaves the surface with no CORS configuration to maintain for it.

## Deployment

The HTTP process publishes no host port. Its address comes from a sidecar or the platform ingress that proxies to it, and upstream gRPC services are reachable by name on the internal network and by nothing outside it. How that is expressed, and what a cutover behind that address entails, is the delivering-swift-services skill's subject.

Configure CORS only for browsers that reach the surface directly. A client whose own server proxies to it is same-origin and needs none.

A gateway needs no database, so it has no migration job and no ordering constraint beyond its upstreams being reachable. A monolith migrates at boot like any service. Give every surface a health route in tier 1 so the platform can probe it without a token.

## The Vapor alternative

A surface on Vapor 4 keeps every rule above and changes three mechanics.

The middleware is swift-authentication-vapor's `BearerAuthenticationMiddleware`, an `AsyncMiddleware` over an identity that is `Authenticatable & Sendable`; `UserIdentity` needs that conformance declared in the surface's target. It logs the identity in to `request.auth`, so `guardMiddleware()` and `req.auth.require(UserIdentity.self)` are the requiring tier, and the admin check is a route-group middleware rather than a context conversion, since Vapor has no request-context chain. `UserSettingsMiddleware` has a Vapor form that writes the tenant setting into `request.serviceContext`.

Vapor 4 bridges its responder chain through event-loop futures, so a task-local bound in middleware does not reach a route. The middleware therefore also writes the principal into `request.serviceContext`, and that is where a route reads it. A use case whose transaction must carry the tenant, or an outgoing gRPC call that must carry the caller's token, runs under it:

```swift
app.get("orders") { req in
    try await ServiceContext.withValue(req.serviceContext) {
        try await listOrdersUseCase(subject: try req.auth.require(UserIdentity.self))
    }
}
```

Tiers are route groups: session-issuing routes on the bare application, an identifying group with the bearer middleware and the settings middleware, and a guarded group with `UserIdentity.guardMiddleware()` on top. The same structural rule holds — no path exception inside a middleware.

## Tests

Compose the application in tests exactly as the composition root does, over mocks of the controllers' collaborators — mocked use-case protocols for a module's surface, one mocked generated client protocol per proto service for a gateway — and a real `JWTIssuer<UserIdentity>` and `JWTAuthenticator<UserIdentity>` over a throwaway Ed25519 key, so the middleware is exercised as shipped, not mocked. Drive it with HummingbirdTesting's `.router` (or `VaporTesting` on Vapor). Cover the tier matrix: anonymous → `401`, a token whose subject is not a user id → `401` from the verifier, the user and admin paths, and each error translation. What a use case decides is covered by its own tests (see [testing.md](testing.md)), so a surface test asserts routing, identification, conversion, and status, not business rules.
