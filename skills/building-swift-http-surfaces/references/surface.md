# The HTTP surface

How HTTP is put on the system: the target that owns it, the OpenAPI document, the request contexts, the router tiers, the middleware that identifies a caller and binds the tenant, the controllers, the conversions, the error translation, and the router and application sections of the composition root. The same surface serves two shapes with one set of rules; only the controller's collaborator differs:

- **A module's HTTP transport.** Each module has an `<Module>HTTP` target whose controllers call the module's use-case protocols directly; a monolith's one executable mounts every module's controllers on one router, and a service mounts its own.
- **A gateway in front of services.** A package of its own, `<organization>-api`, whose controllers call generated gRPC client protocols and forward the caller's token to the user-facing upstreams. Its package, manifest, and composition root are in [gateway.md](gateway.md); every rule below applies to it too.

Hummingbird is the default framework; the Vapor section at the end covers what changes on Vapor 4.

## Contents

- Where HTTP lives
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

An `<Module>HTTP` target owns that module's OpenAPI document and generated types, its controllers, its schema conversions, its use-case problem conformances, and its route registration. It links `Hummingbird`, `HummingbirdAuth`, `OpenAPIRuntime`, `<Project>Authentication`, `Logging`, and its own module's Core; never Postgres, never another module's targets. The types a module's surface shares with every other module's — the request contexts, the error middleware, the problem types — are hand-written in a `<Project>HTTP` target the module targets link, so the surface has one vocabulary. A service folds them into its single `<Service>HTTP`.

Controllers over use cases hold use-case protocol existentials, exactly as a gRPC producer adapter does, and call them with `subject:` or `input:` from the context:

```swift
package struct ItemController: Sendable {
    private let createItemUseCase: any CreateItemUseCaseProtocol
    private let listItemsUseCase: any ListItemsUseCaseProtocol

    package func addPublicRoutes(to group: RouterGroup<BasicRequestContext>) { ... }        // input:
    package func addAuthenticatedRoutes(to group: RouterGroup<IdentityRequestContext>) { ... }  // subject:input:
}
```

The transport target is what keeps a module movable. When a module becomes a service, its `<Module>HTTP` target moves into the new package unchanged; if browsers keep reaching it through a gateway instead, the gateway's controllers take the same routes and conversions over the new service's client protocols — a different collaborator, the same contract.

## The OpenAPI document is the contract

Keep `openapi.yaml` in the generating target's directory beside `openapi-generator-config.yaml`. That is where the generator plugin looks. Do not keep it elsewhere and reach for it with `resources: [.copy("../../Docs/openapi.yaml")]`: the relative path escapes the target directory, which SwiftPM warns about, and the copy exists only to satisfy a lookup the convention already performs.

Generate types only:

```yaml
generate:
  - types
accessModifier: package
```

Routes are registered by hand on Hummingbird, so generated server stubs would be a second routing mechanism maintained for the same endpoints. Use `package`, not `public` — the types cross target boundaries inside one package.

The rule is one routing mechanism and one contract; which one is a project choice. Types-only with hand-registered routes is the default for a project that wants the framework's own APIs to carry the surface: Hummingbird's `RequestContext` chain, route groups, and middleware, or Vapor's route collections and `req.auth`. The tiers below are those APIs, and a tier is a group. The alternative is the generator's server side: `generate: [types, server]` plus the framework's transport package, `OpenAPIHummingbird` from swift-openapi-hummingbird or `OpenAPIVapor` from swift-openapi-vapor, so the generated `APIProtocol` is implemented once and registered on the router with `registerHandlers(on:)`. It is a valid surface, for a team that wants the compiler to prove the document and the handlers agree, at the cost of tiering by middleware on the generated transport rather than by route group, and it is chosen once per project, never per route. Either way the document stays in the target that serves it and the generated types stay out of Core.

One document per module, in the target that serves it. In a monolith each `<Module>HTTP` holds its module's document, which is that module's contract and moves with the module the day it becomes a service; the problem document is a hand-written type in `<Project>HTTP`, not a generated schema, so no two documents need to define the same schema. A service has one document, in `<Service>HTTP`, and a gateway one, in `API`. Unimplemented paths in a document cost nothing while types are all that is generated, so the document can lead the implementation and serve as the checklist.

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

`AdminRequestContext` adds a security gate using verified JWT role claims without database lookups. Apply it to individual verbs or a whole administrative route collection. The owning use case still enforces the role, resource, and business permissions required by its own contract and tests them there; an optional API collection restriction supplements those checks.

## Router tiers

Register routes in three tiers, and let the tier decide what runs:

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
    .add(middleware: UserSettingsMiddleware())

// Tier 3 — a caller is required.
let authenticated = identified.add(middleware: IsAuthenticatedMiddleware())
```

`BearerAuthenticationMiddleware` comes from swift-authentication-hummingbird's `AuthenticationHummingbird`; it takes any `Authenticator<String, UserIdentity>`, sets the context's `identity`, and binds the `Principal<UserIdentity, String>` in `ServiceContext` that the tenant middleware and the propagating interceptor read. A target that builds the tiers links `Authentication` to name the authenticator protocol and `AuthenticationHummingbird` for the middleware — the executable in a monolith or a service, `API` in a gateway whose router builder takes the authenticator — and every surface target links `<Project>Authentication` for `UserIdentity`; the key, and `AuthenticationJWT`, reach only the executable.

Tier 1 exists for the same reason the session-issuing RPCs take their tokens in the request message rather than as a bearer credential: it is that rule, one transport over. Token refresh sends the refresh token in the `Authorization` header, and a refresh token is a database row rather than a signed one. An authenticating middleware applied to it verifies that value as a claim payload, fails, and returns `401` before the handler is reached — so the route cannot succeed at any point, for any client. Registering it in the tier with no authenticating middleware makes that structural.

Tier 2 is where a route that reads differently for a known caller belongs — a catalogue that is public but richer once logged in. Do not collapse tiers 2 and 3; identifying and requiring are separate decisions here exactly as they are on gRPC.

## The tenant on HTTP

On gRPC the bound user becomes the tenant setting through `UserSettingsInterceptor`; on HTTP the same job is `UserSettingsMiddleware`, its HTTP counterpart in `<Project>Persistence`, added to the identifying tier right after the bearer middleware. It reads `ServiceContext.current?.user`, and when a user is bound runs the rest of the request under a `ServiceContext` carrying `PostgresSettings.user(_:)` — the one setting, `app.caller_user_id` — so every transaction a use case begins during the request applies it and the tenant policy sees the caller. With no user bound it binds nothing, and a policy then admits no rows.

A gateway has no database and no tenant middleware: the setting is applied where the transaction runs, by the service the token is forwarded to. A monolith or an HTTP-serving service with a tenant table applies it here, and the monolith is the place to notice that the token is verified exactly once — at this middleware — because no process boundary is crossed between it and the tables.

## Route design

Authorization is a property of the method-and-resource pair. A resource with two audiences is one resource at one path, with one shape in the document, and three mechanisms carry the distinction:

- **Method.** Reads open, writes admin: `GET /items` alongside `POST /items`.
- **Collection versus item.** `GET /users` is inherently an administrative capability where `GET /profile` is not.
- **Sub-resources.** `/users/{id}/orders` for an administrator, a caller-scoped route for everyone else.

Express the administrative half as a context group at the same path:

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
- Over services, in a gateway: generated client protocols, one per `<Entity>Service` the resource speaks. Every tier calls the same stub; the forwarded token, present only when the tier bound a principal, is what the service's handlers check:

```swift
package struct ItemController: Sendable {
    private let client: <Organization>_Catalog_V1_ItemService.ClientProtocol

    package func addPublicRoutes(to group: RouterGroup<BasicRequestContext>) { ... }
    package func addAuthenticatedRoutes(to group: RouterGroup<IdentityRequestContext>) { ... }
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

A create may take an idempotency key (see *Idempotent writes* in the building skill's [persistence reference](../../building-swift-services/references/persistence.md)) that the HTTP client has no natural way to supply — an administrator creating a catalogue row does not hold a stable operation id. Keep the key out of the OpenAPI request and mint one in the conversion, so the HTTP surface stays clean while the create contract and its own unique constraints still hold. This is not the same as idempotency: a fresh key per request means each HTTP call is a new logical attempt, and true de-duplication rests on the resource's unique column (a provider's price id, an email). Expose the key at HTTP only when the client genuinely retries a specific operation and can carry the same key across attempts.

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

The composition root — a monolith mounting every module's controllers, a service's `serve` command adding HTTP beside gRPC — follows the building skill's [composition reference](../../building-swift-services/references/composition.md) for Configuration, Logging, Infrastructure, Composition, and Lifecycle, and adds two sections after Composition: **Router** and **Hummingbird**. A gateway's root is in [gateway.md](gateway.md#composition-root).

Under **Router**, build one router on `BasicRequestContext` and register every module's controllers in the three tiers above. The tiers are the same for a module and for a gateway; what differs is that a module's tier 2 carries `UserSettingsMiddleware` after the bearer middleware wherever tenant tables exist, so the caller the middleware bound becomes the setting the policies read:

```swift
// MARK: - Router
let router = Router(context: BasicRequestContext.self)
router.add(middleware: ErrorMiddleware())
router.add(middleware: LogRequestsMiddleware(.info))

let v1 = router.group("v1")

// Tier 1: no caller. Session-issuing routes and the health route.
usersController.addPublicRoutes(to: v1.group("auth"))
v1.get("health") { _, _ in HTTPResponse.Status.ok }

// Tier 2: a caller if there is one. The settings middleware turns a bound user into the tenant setting.
let identified = v1.group(context: IdentityRequestContext.self)
    .add(middleware: BearerAuthenticationMiddleware<IdentityRequestContext>(authenticator: userAuthenticator))
    .add(middleware: UserSettingsMiddleware())
itemController.addIdentifiedRoutes(to: identified.group("items"))

// Tier 3: a caller is required.
let authenticated = identified.add(middleware: IsAuthenticatedMiddleware())
itemController.addAuthenticatedRoutes(to: authenticated.group("items"))
usersController.addAuthenticatedRoutes(to: authenticated.group("profile"))
```

`BearerAuthenticationMiddleware` comes from `AuthenticationHummingbird` and takes any `Authenticator<String, UserIdentity>`; `UserSettingsMiddleware` comes from `<Project>Persistence`, beside `UserSettingsInterceptor`, and reads what the bearer middleware bound, so it follows it and never precedes it. Keep the path prefix here and the routes in the controllers, so one file shows the whole surface and each controller stays movable. A monolith with a dozen modules has a dozen `add…Routes` lines per tier and nothing else.

Under **Hummingbird**, build the application from the router and the listener read by `ApplicationConfiguration(reader:)` scoped to `http.server`:

```swift
// MARK: - Hummingbird
let application = Application(
    router: router,
    configuration: ApplicationConfiguration(reader: config.scoped(to: "http.server")),
    logger: logger
)
```

The application publishes no host port of its own; the address comes from the ingress that proxies to it (*Deployment* below). On Vapor 4 the same sections build a `Vapor.Application`, register the tiers as route groups, and run under `ServiceContext.withValue(req.serviceContext)` where a route calls out, as *The Vapor alternative* below describes.


With Temporal, the serving process also builds one long-lived `TemporalClient` and injects workflow-client adapters into the use cases, exactly as a gRPC root does. A process serving both transports has one root, one set of use cases, and one `ServiceGroup` holding the application and the gRPC server.

## One surface or two

Default to one target, one document, and one application. Authorization by context conversion is enough to keep administrative routes out of ordinary hands, and a second surface doubles the generated type set.

Split into two Hummingbird applications — two routers, two ports, one `ServiceGroup` — only when the administrative routes must not be publicly routable at all. That buys something a role check cannot: the routes are absent from the public router's tree, so no ordering mistake can expose them, and the port is simply never published.

Before splitting, check whether the administrative client removes the need. A browser client served by its own process can proxy same-origin to an unpublished port, which gets the isolation without splitting Swift targets, and leaves the surface with no CORS configuration to maintain for it.

## Deployment

The HTTP process publishes no host port. Its address comes from a sidecar or the platform ingress that proxies to it, and upstream gRPC services are reachable by name on the internal network and by nothing outside it. How that is expressed, and what a cutover behind that address entails, is the delivering-swift-services skill's subject.

Configure CORS only for browsers that reach the surface directly. A client whose own server proxies to it is same-origin and needs none.

A gateway needs no database, so it has no migration job and no ordering constraint beyond its upstreams being reachable. A monolith migrates at boot like any service. Give every surface a health route in tier 1 so the platform can probe it without a token.

## The Vapor alternative

A surface on Vapor 4 keeps every rule above and changes three mechanics, in a gateway and in a module's `<Module>HTTP` alike. Hummingbird is the default because its request-context chain carries the tiers in the type system; a project on Vapor chooses it once, for every surface.

The middleware is swift-authentication-vapor's `BearerAuthenticationMiddleware`, an `AsyncMiddleware` over an identity that is `Authenticatable & Sendable`; `UserIdentity` needs that conformance declared in the surface's target. It logs the identity in to `request.auth`, so `guardMiddleware()` and `req.auth.require(UserIdentity.self)` are the requiring tier, and the admin check is a route-group middleware rather than a context conversion, since Vapor has no request-context chain.

Vapor 4 bridges its responder chain through event-loop futures, so a task-local bound in middleware does not reach a route. The middleware therefore also writes the principal into `request.serviceContext`, and that is where a route reads it. The Vapor form of `UserSettingsMiddleware`, in `<Project>Persistence` beside the Hummingbird one, follows the same path: it reads the principal from `request.serviceContext` and writes `postgresSettings = .user(identity)` back into it, rather than binding a task-local nothing downstream would see. The org layer ships the Hummingbird middleware by default and adds the Vapor one when the project uses Vapor. A use case whose transaction must carry the tenant, or an outgoing gRPC call that must carry the caller's token, then runs under that context:

```swift
app.get("orders") { req in
    try await ServiceContext.withValue(req.serviceContext) {
        try await listOrdersUseCase(subject: try req.auth.require(UserIdentity.self))
    }
}
```

In a module's surface, a controller is a `RouteCollection` holding the module's use-case protocols, with one `boot(routes:)` that registers into the groups the composition root hands it, and the `ServiceContext.withValue` wrapper sits in the handler, once, around the use-case call. Conversions stay in `Schemas/Requests/` and `Schemas/Responses/` as `X+Schema.swift`, and problem details come from a custom `ErrorMiddleware` registered first on the application, mapping the use case's typed errors and `Abort` to `application/problem+json` exactly as the Hummingbird `ErrorMiddleware` does. A gateway's controller is the same collection over generated client protocols with `X+RPC.swift` conversions.

Tiers are route groups: session-issuing routes on the bare application, an identifying group with the bearer middleware and the settings middleware, and a guarded group with `UserIdentity.guardMiddleware()` on top; the admin group adds a middleware that requires `.admin` from `req.auth` and answers `403`. As on Hummingbird, the group a route is registered in decides what runs.

## Tests

Compose the application in tests exactly as the composition root does, over mocks of the controllers' collaborators — mocked use-case protocols for a module's surface, one mocked generated client protocol per proto service for a gateway — and a real `JWTIssuer<UserIdentity>` and `JWTAuthenticator<UserIdentity>` over a throwaway Ed25519 key, so the middleware is exercised as shipped, not mocked. Drive it with HummingbirdTesting's `.router` (or `VaporTesting` on Vapor). Cover the tier matrix: anonymous → `401`, a token whose subject is not a user id → `401` from the verifier, the user and admin paths, and distinct error mappings. Exercise a shared status mapper once with explicit input/expected pairs rather than repeating it through every controller. What a use case decides is covered by its own tests (see the building skill's [testing reference](../../building-swift-services/references/testing.md)), so a surface test asserts routing, identification, conversion, and status, not business rules.
