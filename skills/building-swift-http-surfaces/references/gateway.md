# The gateway

## Contents

- The package
- Source tree
- Manifest
- Composition root
- Tests

The HTTP transport of a system whose modules are services: one package, `<organization>-api`, two targets, no data. Every rule in [surface.md](surface.md) applies — the OpenAPI document, the contexts, the tiers, the controllers, the conversions, the problem details — with generated gRPC client protocols in place of use cases. This file holds what only the gateway has.

## The package

When the modules are services, the HTTP surface is its own process. Name the package `<organization>-api`, not `-gateway`: the naming grammar refuses `gateway` as a type name, and the thing that actually gateways — routing, TLS termination, rate limiting — is the ingress in front of this process. What this package holds is hand-written controllers mapping one contract onto another, which is an edge service.

```text
<organization>-api
├── API ────────→ generated OpenAPI types, contexts, middleware, controllers, conversions
└── <Project> ──→ API   # command tree, configuration, clients, lifecycle
```

Two targets, not four. A gateway owns no entities, no repositories, and no database, so `Core` and `Postgres` targets would be empty. Do not add an `APICore` to mirror the service shape: the only candidates for it are the request contexts and the problem types, and both are transport concerns that belong beside the controllers that use them.

| Target | Owns | Must not own |
| --- | --- | --- |
| `API` | Generated OpenAPI types, request contexts, error middleware and problem types, controllers, RPC conversions, and `<Project>API.swift`, which assembles the router and its tiers from the controllers and an authenticator it is handed | Environment reading, client or authenticator construction, logging setup, `@main` |
| `<Project>` | ArgumentParser command tree, configuration, client and authenticator construction — the target that builds the `JWTAuthenticator` from the key — the application, and lifecycle | Route handlers, tiers, schema conversion, business rules |

`API` links `Hummingbird`, `HummingbirdAuth`, `OpenAPIRuntime`, `Authentication` (to take any `Authenticator<String, UserIdentity>`), `AuthenticationHummingbird`, `<Project>Authentication`, `GRPCCore` for the `RPCError` conformance, and one `<Upstream>Protos` per upstream; the executable adds `AuthenticationJWT`, `AuthenticationGRPC`, `JWTKit`, the gRPC transport, and the upstream protos it dials. The gateway routes only intended public and user operations; internal descriptors remain private.

## Source tree

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
        ├── InMemoryProvider+ApplicationDefaults.swift
        ├── TimedCertificateReloader.Configuration+ConfigReader.swift
        ├── EdDSA.PublicKey+ConfigReader.swift
        └── HTTP2ClientTransport.Posix.TransportSecurity+ConfigReader.swift
```

No `Database/`, no migrations, no `PostgresConfiguration`: a gateway owns no data.

## Manifest

```swift
.target(
    name: "API",
    dependencies: [
        .product(name: "Hummingbird", package: "hummingbird"),
        .product(name: "HummingbirdAuth", package: "hummingbird-auth"),
        .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
        .product(name: "Authentication", package: "swift-authentication"),           // names the Authenticator protocol
        .product(name: "AuthenticationHummingbird", package: "swift-authentication-hummingbird"),
        .product(name: "<Project>Authentication", package: "<project>-core"),
        .product(name: "GRPCCore", package: "grpc-swift-2"),                         // RPCError, for the problem conformance
        .product(name: "ServiceContextModule", package: "swift-service-context"),
        .product(name: "<Upstream>Protos", package: "<project>-protos"),             // one per upstream
        .product(name: "Logging", package: "swift-log"),
    ],
    swiftSettings: swiftSettings,
    plugins: [
        .plugin(name: "OpenAPIGenerator", package: "swift-openapi-generator")
    ]
),
.executableTarget(
    name: "<Project>",
    dependencies: [
        "API",
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
        .product(name: "Configuration", package: "swift-configuration"),
        .product(name: "Hummingbird", package: "hummingbird"),
        .product(name: "AuthenticationJWT", package: "swift-authentication-jwt"),
        .product(name: "AuthenticationGRPC", package: "swift-authentication-grpc"),  // the propagating interceptor
        .product(name: "<Project>Authentication", package: "<project>-core"),
        .product(name: "JWTKit", package: "jwt-kit"),
        .product(name: "GRPCCore", package: "grpc-swift-2"),
        .product(name: "GRPCNIOTransportHTTP2", package: "grpc-swift-nio-transport"),
        .product(name: "GRPCServiceLifecycle", package: "grpc-swift-extras"),
        .product(name: "NIOCertificateReloading", package: "swift-nio-extras"),
        .product(name: "<Upstream>Protos", package: "<project>-protos"),             // one per upstream
        .product(name: "ServiceContextModule", package: "swift-service-context"),
        .product(name: "Logging", package: "swift-log"),
        .product(name: "LoggingLoki", package: "swift-log-loki"),
        .product(name: "ServiceLifecycle", package: "swift-service-lifecycle"),
    ],
    swiftSettings: swiftSettings
),
.testTarget(
    name: "APITests",
    dependencies: [
        "API",
        .product(name: "HummingbirdTesting", package: "hummingbird"),
        .product(name: "AuthenticationJWT", package: "swift-authentication-jwt"),
        .product(name: "JWTKit", package: "jwt-kit"),
        .product(name: "<Project>Authentication", package: "<project>-core"),
        .product(name: "<Upstream>Protos", package: "<project>-protos"),
    ],
    swiftSettings: swiftSettings
),
```

No `postgres-nio`, no `postgres-migrations`, no `swift-persistence`: a gateway declares no persistence package at all.

## Composition root

A gateway's `serve` follows the building skill's section order — Configuration, Logging, Infrastructure, Composition, Router, Hummingbird, Lifecycle — with no gRPC section, and its Infrastructure holds no database. Under Infrastructure, build the authenticator, `JWTAuthenticator<UserIdentity>` over the public key by path through the EdDSA initializer `<Project>Authentication` adds, exactly as the building skill's [identity reference](../../building-swift-services/references/identity-and-access.md) describes, and one `GRPCClient` per upstream, each with a required host and port and the stack's mTLS client factory and `ServiceConfig.defaults` from the building skill's [transport security factories](../../building-swift-services/references/composition.md#transport-security-factories). Every upstream is one connection and two audiences, so the caller's token is resent only on the proto service that takes one, through one interceptor applied per descriptor:

```swift
// MARK: - Infrastructure
let tlsConfig = config.scoped(to: "tls")
let userAuthenticator = await JWTAuthenticator<UserIdentity>(publicKey: try EdDSA.PublicKey(config: config.scoped(to: "jwt")))
let propagation = BearerPropagationInterceptor<UserIdentity>()

let usersConfig = config.scoped(to: "grpc.users")
let usersClient = GRPCClient(
    transport: try .http2NIOPosix(
        target: .dns(
            host: try usersConfig.requiredString(forKey: "host"),
            port: try usersConfig.requiredInt(forKey: "port")
        ),
        transportSecurity: try .mTLS(config: tlsConfig, certificateReloader: certificateReloader),
        serviceConfig: .defaults
    ),
    interceptorPipeline: [
        .apply(propagation, to: .services([<Organization>_Users_V1_UserService.descriptor, <Organization>_Users_V1_UserAdminService.descriptor]))
    ]
)
```

Under Composition, wrap each client in one generated stub per proto service, `UserPublicService.Client(wrapping:)`, `UserService.Client(wrapping:)`, and `UserAdminService.Client(wrapping:)` over the same `GRPCClient`, and hand them to the controller; admin routes, behind `AdminRequestContext`, call the admin stub, and a self route sends no user id — the forwarded token names the caller. The public stub is dialled with nothing, which is what the session-issuing RPCs expect: they run before any caller exists, so there is no token to forward. The gateway exposes only intended public, self, and admin operations; its mTLS credential must not be treated as permission to publish internal routes.

Under Router, call `API`'s router builder, which registers the same three tiers as a module's, without `UserSettingsMiddleware`: a gateway has no database for the setting to reach, and the tenant is bound again, from the forwarded token, inside the service that owns the rows. Under Hummingbird, `ApplicationConfiguration(reader:)` scoped to `http.server`. Under Lifecycle, the application and every client in one `ServiceGroup`:

```swift
let serviceGroup = ServiceGroup(
    services: [lokiProcessor, certificateReloader, authenticationClient, usersClient, application],
    gracefulShutdownSignals: [.sigint, .sigterm],
    logger: logger
)
```

The gateway publishes no host port and needs no migration job; give it a health route in tier 1 so the platform can probe it without a token. Its tests are under *Tests* below.

## Tests

Compose the router in `APITests` exactly as `serve` does, over one mocked generated client protocol per proto service and a real `JWTIssuer<UserIdentity>` and `JWTAuthenticator<UserIdentity>` over a throwaway Ed25519 key, and drive it with HummingbirdTesting's `.router`. Cover the tier matrix — a session-issuing route reaches its handler carrying an unverifiable bearer token, a protected route carrying the same token answers `401`, anonymous `401`, a non-administrator `403` on an administrative route — each controller's conversions, including a malformed upstream value answering an error rather than disappearing, and the `RPCError` problem mapping once, with explicit code/status pairs. Assert that a public route reaches the public stub and a user route the user stub; that split is the gateway's own contract. What the services decide is their tests'.
