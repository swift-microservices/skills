# The HTTP surface

How HTTP is put on the system: the target that owns it, the OpenAPI document, the request contexts, the router tiers, the tenant middleware, the controllers, the conversions, the error translation, and the Router and Hummingbird sections of the composition root. One set of rules serves two shapes; only the controller's collaborator differs:

- **A module's HTTP transport.** Each module has an `<Module>HTTP` target whose controllers call the module's use-case protocols directly; a monolith's one executable mounts every module's controllers on one router, and a service mounts its own.
- **A gateway in front of services.** A package of its own, `<organization>-api`, whose controllers call generated gRPC client protocols and forward the caller's token on each upstream's `<Entity>Service` descriptors. Its package, manifest, router builder, composition root, and tests are in [gateway.md](gateway.md); every rule below applies to it too.

Use Hummingbird 2.28.0 or later by default. A surface on Vapor 4 is in [vapor.md](vapor.md); the client SDK generated from a surface's document is in [client-sdk.md](client-sdk.md).

## Contents

- [Where HTTP lives](#where-http-lives)
- [The OpenAPI document is the contract](openapi-document.md#the-openapi-document-is-the-contract)
- [The document as a client contract](openapi-document.md#the-document-as-a-client-contract)
- [Request contexts](#request-contexts)
- [Router tiers](#router-tiers)
- [The tenant on HTTP](#the-tenant-on-http)
- [Route design](#route-design)
- [Controllers](#controllers)
- [Schema conversion](#schema-conversion)
- [Idempotency keys the client does not carry](#idempotency-keys-the-client-does-not-carry)
- [Error translation](error-translation.md#error-translation)
- [Composition](#composition)
- [One surface or two](#one-surface-or-two)
- [Deployment](#deployment)
- [Tests](#tests)

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

An `<Module>HTTP` target owns that module's OpenAPI document and generated types, its controllers, its schema conversions, its use-case problem conformances, and its route registration. It links `Hummingbird`, `HummingbirdAuth`, `HTTPTypes`, `OpenAPIRuntime`, `<Project>Authentication`, `Logging`, and its own module's Core; never Postgres, never another module's targets. The types every module's surface shares — the request contexts, the error middleware, the problem types — are hand-written in a `<Project>HTTP` target the module targets link, so the surface has one vocabulary. A service folds them into its single `<Service>HTTP`.

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

    /// The caller of a "the caller's own" route.
    package func requireUser() throws -> UserIdentity {
        try requireIdentity()
    }
}
```

Carry `coreContext` across. Do not rebuild it with `.init(source: context)`, which is what Hummingbird's own `ChildRequestContext` documentation shows: `CoreRequestContextStorage`'s `init(source:)` starts `parameters` and `endpointPath` empty, and path parameters are extracted before the child is constructed. Rebuilding silently discards them, so a route declared with `:id` matches, runs, and then cannot find its own parameter.

Every token is a person's — a process proves itself with its certificate and never reaches an HTTP surface — so `requireUser()` is `requireIdentity()` under the name the caller's-own routes use for what they mean.

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

Absent is `401`, because presenting a token could change the answer; insufficient is `403`, because it could not. The gate reads verified JWT role claims without database lookups, around one verb or a whole administrative route collection; the owning use case still enforces the role, resource, and business permissions of its own contract.

## Router tiers

Register routes in three tiers, and let the tier decide what runs. This is the Router section of a module's composition root; a gateway's router builder registers the same tiers without `UserSettingsMiddleware`:

```swift
// MARK: - Router
let router = Router(context: BasicRequestContext.self)
router.add(middleware: ErrorMiddleware())
router.add(middleware: LogRequestsMiddleware(.info))

let v1 = router.group("v1")

// Tier 1: no caller. Session-issuing routes and the health route.
v1.get("health") { _, _ -> HTTPResponse.Status in .ok }
usersController.addPublicRoutes(to: v1.group("auth"))

// Tier 2: a caller if there is one; anonymous requests still arrive.
let identified = v1.group(context: IdentityRequestContext.self)
    .add(middleware: BearerAuthenticationMiddleware<IdentityRequestContext>(authenticator: userAuthenticator))
    .add(middleware: UserSettingsMiddleware())
itemController.addIdentifiedRoutes(to: identified.group("items"))

// Tier 3: a caller is required.
let authenticated = identified.group().add(middleware: IsAuthenticatedMiddleware())
itemController.addAuthenticatedRoutes(to: authenticated.group("items"))
usersController.addAuthenticatedRoutes(to: authenticated.group("profile"))
```

Take tier 3 from `identified.group()`. `RouterGroup.add(middleware:)` adds to the group it is called on and returns it, applying to routes registered afterwards, so `identified.add(middleware: IsAuthenticatedMiddleware())` would make every tier-2 route registered after it require a caller.

`BearerAuthenticationMiddleware` comes from swift-authentication-hummingbird's `AuthenticationHummingbird`. It takes any `Authenticator<String, UserIdentity>`, sets the context's `identity`, and binds the `Principal<UserIdentity, String>` in `OperationContext` that the tenant middleware and the propagating interceptor read. The target that builds the tiers links `Authentication` to name the authenticator protocol and `AuthenticationHummingbird` for the middleware — the executable in a monolith or a service, `API` in a gateway — and every surface target links `<Project>Authentication` for `UserIdentity`; the key and `AuthenticationJWT` reach only the executable.

Tier 1 exists because refresh sends the refresh token — a database row, not a signed token — in the `Authorization` header; an authenticating middleware would fail to verify it and answer `401` before the handler ran. Tier 2 holds a route that reads differently for a known caller, a catalogue that is public but richer once signed in. Never collapse tiers 2 and 3: identifying and requiring are separate decisions here exactly as they are on gRPC.

## The tenant on HTTP

`UserSettingsMiddleware`, from `<Project>Persistence` beside `UserSettingsInterceptor`, is the HTTP counterpart of that interceptor. It follows the bearer middleware in the identifying tier, never precedes it, and reads `OperationContext.current.user`: when a user is bound it runs the rest of the request under an `OperationContext` carrying `PostgresSettings.user(_:)` — the one setting, `app.caller_user_id` — so every transaction a use case begins applies it and the tenant policy sees the caller. With no user bound it binds nothing, and a policy then admits no rows.

Add it wherever a module has tenant tables. A gateway has no database and no tenant middleware: the service the token is forwarded to applies the setting where the transaction runs. In a monolith the token is verified exactly once, at the bearer middleware, because no process boundary lies between it and the tables.

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

Two limits:

- Two operations that share a method and path but differ in scope — a caller-scoped list and an administrative list of everything — stay separate paths over separate use cases; a query parameter that switches between them is one operation with two meanings.
- Sessions, provider webhooks, and checkout callbacks are workflows, not resources: `POST /payments/<provider>/webhook` is the honest spelling. Do not restructure a working verb-shaped route to satisfy a taxonomy.

A check that depends on a path parameter — this record if it is yours, any record if you are an administrator — is not one route deciding two ways. The caller's own route names no user and calls the caller's-own use case, which reads under the tenant policy; an administrator's read of any record is a separate route behind `AdminRequestContext`, calling a separate use case, or a separate RPC from a gateway. The use case decides in both, so a gateway handler never adds a resource check of its own.

## Controllers

One `XController` per resource, holding protocols rather than concrete types so a test can substitute them:

- Over use cases, in a module's own surface: the use-case protocol existentials the module's Core declares, one per operation the resource exposes. The controller reads the caller from the context and passes it as `subject:`; a public route passes `input:` alone.
- Over services, in a gateway: generated client protocols, one per `<Entity>Service` the resource speaks. Every tier calls the same stub; the forwarded token, present only when the tier bound a principal, is what the service's handlers check:

```swift
package struct ItemController: Sendable {
    private let client: any <Organization>_Catalog_V1_ItemService.ClientProtocol

    package init(client: any <Organization>_Catalog_V1_ItemService.ClientProtocol) {
        self.client = client
    }

    package func addPublicRoutes(to group: RouterGroup<BasicRequestContext>) { ... }
    package func addAuthenticatedRoutes(to group: RouterGroup<IdentityRequestContext>) { ... }
}
```

Name the registration methods for the tier they mount into. A gateway controller may reach more than one service — an item's record is owned by catalog while its stock level is owned by inventory — because which service answers a resource is the gateway's problem, not the client's. A module controller reaches its own module's use cases only; a route that needs another module's answer goes through the use case, which holds the other module's protocol.

Keep path prefixes in the composition root or the router builder and the routes in the controllers, so one file shows the whole surface and each controller stays movable.

## Schema conversion

Put conversions in `Schemas/Requests/` and `Schemas/Responses/`, and conversions of enums several schemas share in `Schemas/Shared/`. In a gateway they are `X+RPC.swift` and convert between the generated OpenAPI types and protobuf messages, matching the producer-side `Protobuf/` convention. In a module's surface they are `X+Schema.swift` and convert between the generated OpenAPI types and Core's inputs and entities, exactly as `X+Protobuf.swift` does for gRPC; transport validation — ranges, enum recognition, ids from protobuf strings — happens in that initializer, and generated schema types never reach Core.

Make a conversion throw rather than drop:

```swift
extension Components.Schemas.ItemResponse {
    init(_ item: <Organization>_Catalog_V1_Item) throws {
        guard let id = UUID(uuidString: item.id) else {
            throw HTTPError(.internalServerError, message: "The item record is malformed.")
        }
        self.init(id: id, name: item.name)
    }
}
```

A shared enum converts both ways, and an unrecognized wire value is a malformed record:

```swift
extension Components.Schemas.ItemKind {
    init(_ kind: <Organization>_Catalog_V1_ItemKind) throws {
        switch kind {
        case .physical: self = .physical
        case .digital: self = .digital
        case .unspecified, .UNRECOGNIZED:
            throw HTTPError(.internalServerError, message: "The item record is malformed.")
        }
    }
}
```

A `compactMap` over a malformed field returns a shorter list and a `200`, so a client sees a record that has disappeared rather than an error anybody investigates. A value the upstream should never have produced is a fault in that upstream and should say so.

## Idempotency keys the client does not carry

A create may take an idempotency key (see *Idempotent writes* in the building skill's [persistence reference](../../building-swift-services/references/persistence.md)) that the HTTP client has no natural way to supply — an administrator creating a catalogue row does not hold a stable operation id. Keep the key out of the OpenAPI request and mint one in the conversion, so the HTTP surface stays clean while the create contract and its unique constraints still hold. A fresh key per request makes each HTTP call a new logical attempt; de-duplication then rests on the resource's unique column (a provider's price id, an email). Expose the key at HTTP only when the client genuinely retries a specific operation and can carry the same key across attempts.

## Composition

The composition root — a monolith mounting every module's controllers, a service's `serve` command adding HTTP beside gRPC — follows the building skill's [composition reference](../../building-swift-services/references/composition.md) for Configuration, Logging, Infrastructure, Composition, and Lifecycle, and adds two sections after Composition: **Router** and **Hummingbird**. A gateway's root is in [gateway.md](gateway.md#composition-root).

**Router** is the code in *Router tiers* above: one router on `BasicRequestContext`, `ErrorMiddleware` and request logging, and every module's controllers in the three tiers. A monolith with a dozen modules has a dozen `add…Routes` lines per tier and nothing else.

**Hummingbird** builds the application from the router and the listener read by `ApplicationConfiguration(reader:)` scoped to `http.server`, served over TLS with the process's leaf and no client certificate (HummingbirdTLS; the reloader is the root's):

```swift
// MARK: - Hummingbird
let application = Application(
    router: router,
    server: try .tls(.http1(), tlsConfiguration: .makeServerConfiguration(certificateReloader: certificateReloader)),
    configuration: ApplicationConfiguration(reader: config.scoped(to: "http.server")),
    logger: logger
)
```

With Temporal, the serving process also builds one long-lived `TemporalClient` and injects workflow-client adapters into the use cases, exactly as a gRPC root does. A process serving both transports has one root, one set of use cases, and one `ServiceGroup` holding the application and the gRPC server.

## One surface or two

Default to one application and one router, over the documents the surface already has, with the administrative routes in the same router: the context conversion keeps them out of ordinary hands, with the use case deciding behind it, and a second surface doubles the generated type set. Split into two Hummingbird applications — two routers, two ports, one `ServiceGroup` — only when the administrative routes must not be publicly routable at all, so they are absent from the public router's tree and their port is never published. A browser client served by its own process can get the same isolation by proxying same-origin to an unpublished port, without splitting Swift targets.

## Deployment

The HTTP process publishes no host port. Its listener is client-facing: the edge terminates public TLS and its proxy reaches the process over TLS it verifies, with no client certificate, as the delivering skill's [public ingress](../../delivering-swift-services/references/environment.md#public-ingress) contract says; upstream gRPC services are reachable by name on the internal network and by nothing outside it; how that is expressed is the delivering-swift-services skill's subject. Configure CORS (`CORSMiddleware` on the router, before `ErrorMiddleware`) only for browsers that reach the surface directly; a client whose own server proxies to it is same-origin and needs none. Every surface has a health route in tier 1, answering for this process alone, so the platform can probe it without a token. A gateway has no migration job; a monolith migrates at boot like any service.

## Tests

Compose the application in tests exactly as the composition root does, over mocks of the controllers' collaborators — mocked use-case protocols for a module's surface, one mocked generated client protocol per `<Entity>Service` for a gateway — and a real `JWTIssuer<UserIdentity>` and `JWTAuthenticator<UserIdentity>` over a throwaway Ed25519 key, so the middleware runs as shipped. Drive it with HummingbirdTesting's `.router` (`VaporTesting` on Vapor). Cover the tier matrix — anonymous `401` on a requiring route, a token whose subject is not a user id `401` from the verifier, a session-issuing route reaching its handler while carrying an unverifiable token, the user and admin paths with a non-administrator `403` — each route's conversions, and each distinct error mapping. Exercise a shared status mapper once with explicit input/expected pairs rather than through every controller.

What a use case decides is covered by its own tests (the building skill's [testing reference](../../building-swift-services/references/testing.md)), so a surface test asserts routing, identification, conversion, and status, not business rules. A gateway adds one live loopback mTLS suite for what only real connections prove; its harness, mocks, and that suite are in [gateway.md](gateway.md#tests).
