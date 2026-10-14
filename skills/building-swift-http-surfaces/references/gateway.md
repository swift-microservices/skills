# The gateway

## Contents

- [The package](#the-package)
- [Source tree](#source-tree)
- [Manifest](#manifest)
- [The router builder](#the-router-builder)
- [Composition root](#composition-root)
- [Tests](#tests)

The HTTP transport of a system whose modules are services: one package, `<organization>-api`, two targets, no data. Every rule in [surface.md](surface.md) applies — the OpenAPI document, the contexts, the tiers, the controllers, the conversions, the problem details — with generated gRPC client protocols in place of use cases. This file holds what only the gateway has.

## The package

Name the package `<organization>-api`, not `-gateway`: the naming grammar refuses `gateway` as a type name, and routing, public TLS termination, and rate limiting belong to the edge in front of this process. What this package holds is hand-written controllers mapping one contract onto another.

```text
<organization>-api
├── API ────────→ generated OpenAPI types, contexts, middleware, controllers, conversions, the router builder
└── <Project> ──→ API   # command tree, configuration, clients, lifecycle
```

Two targets, not four. A gateway owns no entities, repositories, or database, so `Core` and `Postgres` targets would be empty; do not add an `APICore` for the request contexts and problem types, which are transport concerns that belong beside the controllers.

| Target | Owns | Must not own |
| --- | --- | --- |
| `API` | Generated OpenAPI types, request contexts, error middleware and problem types, controllers, RPC conversions, and `<Project>API.swift`, the router builder | Environment reading, client or authenticator construction, logging setup, `@main` |
| `<Project>` | ArgumentParser command tree, configuration, the `JWTAuthenticator` from the public key, the upstream clients, the router and application, and lifecycle | Route handlers, tiers, schema conversion, business rules |

The gateway routes only intended `<Entity>Service` operations and never an internal descriptor; its mTLS credential is not permission to publish internal routes.

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
│   │               └── RPCError+HTTPProblemResponse.swift
│   └── Schemas/
│       ├── Requests/
│       │   └── CreateItemRequest+RPC.swift
│       ├── Responses/
│       │   └── ItemResponse+RPC.swift
│       └── Shared/
│           └── ItemKind+RPC.swift
└── <Project>/
    ├── <Project>.swift
    ├── Serve/
    │   └── Serve.swift
    └── Configuration/
        ├── InMemoryProvider+ApplicationDefaults.swift
        ├── TimedCertificateReloader.Configuration+ConfigReader.swift
        ├── EdDSA.PublicKey+ConfigReader.swift
        ├── HTTP2ClientTransport.Posix.TransportSecurity+ConfigReader.swift
        ├── HTTP2ClientTransport.Posix.Config+Gateway.swift
        └── ServiceConfig+Defaults.swift
Tests/
└── APITests/
    ├── Support/          # withApp, Dependencies.mocked, TestTokens, respond and Recorder
    ├── Mocks/            # one mock per generated ClientProtocol
    ├── Upstreams/        # the live loopback mTLS suite and its fixtures
    └── <Resource>ControllerTests.swift, AuthorizationTests.swift, ProblemMappingTests.swift
```

The problem plumbing (`ErrorMiddleware`, `Problem`, `HTTPProblemResponse`, the `RPCError` conformance) is the code in [surface.md](surface.md#error-translation). No `Database/`, no migrations, no `PostgresConfiguration`: a gateway owns no data.

## Manifest

Package dependencies follow the building skill's [dependency baseline](../../building-swift-services/references/service-package.md#dependency-baseline), with Hummingbird 2.28.0 or later.

```swift
.target(
    name: "API",
    dependencies: [
        .product(name: "Hummingbird", package: "hummingbird"),
        .product(name: "HummingbirdAuth", package: "hummingbird-auth"),
        .product(name: "HTTPTypes", package: "swift-http-types"),                    // HTTPResponse.Status members in the problem types
        .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
        .product(name: "Authentication", package: "swift-authentication"),           // names the Authenticator protocol
        .product(name: "AuthenticationHummingbird", package: "swift-authentication-hummingbird"),
        .product(name: "<Project>Authentication", package: "<project>-core"),
        .product(name: "GRPCCore", package: "grpc-swift-2"),                         // RPCError, ClientProtocol
        .product(name: "SwiftProtobuf", package: "swift-protobuf"),                  // Google_Protobuf_Empty and other well-known types
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
        .product(name: "HummingbirdTLS", package: "hummingbird"),                    // the listener's server TLS
        .product(name: "AuthenticationJWT", package: "swift-authentication-jwt"),
        .product(name: "AuthenticationGRPC", package: "swift-authentication-grpc"),  // the propagating interceptor
        .product(name: "<Project>Authentication", package: "<project>-core"),
        .product(name: "JWTKit", package: "jwt-kit"),
        .product(name: "GRPCCore", package: "grpc-swift-2"),
        .product(name: "GRPCNIOTransportHTTP2", package: "grpc-swift-nio-transport"),
        .product(name: "GRPCServiceLifecycle", package: "grpc-swift-extras"),
        .product(name: "NIOCertificateReloading", package: "swift-nio-extras"),
        .product(name: "<Upstream>Protos", package: "<project>-protos"),             // one per upstream
        .product(name: "Logging", package: "swift-log"),
        .product(name: "LoggingLoki", package: "swift-log-loki"),
        .product(name: "ServiceLifecycle", package: "swift-service-lifecycle"),
        .product(name: "UnixSignals", package: "swift-service-lifecycle"),           // .sigint and .sigterm
    ],
    swiftSettings: swiftSettings
),
.testTarget(
    name: "APITests",
    dependencies: [
        "API",
        .product(name: "Hummingbird", package: "hummingbird"),
        .product(name: "HummingbirdTesting", package: "hummingbird"),
        .product(name: "HTTPTypes", package: "swift-http-types"),
        .product(name: "NIOFoundationEssentialsCompat", package: "swift-nio"),       // decoding response bodies
        .product(name: "Authentication", package: "swift-authentication"),
        .product(name: "AuthenticationJWT", package: "swift-authentication-jwt"),
        .product(name: "JWTKit", package: "jwt-kit"),
        .product(name: "<Project>Authentication", package: "<project>-core"),
        .product(name: "GRPCCore", package: "grpc-swift-2"),                         // mocks of the generated ClientProtocol
        .product(name: "SwiftProtobuf", package: "swift-protobuf"),
        .product(name: "<Upstream>Protos", package: "<project>-protos"),
        // The live loopback mTLS suite:
        .product(name: "AuthenticationGRPC", package: "swift-authentication-grpc"),
        .product(name: "GRPCNIOTransportHTTP2", package: "grpc-swift-nio-transport"),
        .product(name: "GRPCProtobuf", package: "grpc-swift-protobuf"),
        .product(name: "GRPCServiceLifecycle", package: "grpc-swift-extras"),
        .product(name: "NIOCertificateReloading", package: "swift-nio-extras"),
        .product(name: "OperationContext", package: "swift-operation-context"),
        .product(name: "ServiceLifecycle", package: "swift-service-lifecycle"),
        .product(name: "Logging", package: "swift-log"),
        .product(name: "Crypto", package: "swift-crypto"),
        .product(name: "X509", package: "swift-certificates"),
        .product(name: "SwiftASN1", package: "swift-asn1"),
    ],
    swiftSettings: swiftSettings
),
```

Under `MemberImportVisibility`, a file that names a member of a module imports that module, and the module is a direct dependency of the target: the mocks name `GRPCCore` and `SwiftProtobuf` types in the generated `ClientProtocol` signatures, so `APITests` declares both. No `postgres-nio`, no `postgres-migrations`, no `swift-persistence`: a gateway declares no persistence package at all.

## The router builder

`<Project>API.swift` in `API` assembles the whole surface from a `Dependencies` value — the authenticator and one generated client existential per `<Entity>Service` — so `serve` and the tests mount exactly the same routes:

```swift
package import Authentication
import AuthenticationHummingbird
package import CatalogProtos
package import Hummingbird
import HummingbirdAuth
package import <Project>Authentication
package import UsersProtos

package struct <Project>API: Sendable {
    /// One client per proto service. Each carries the caller's token upstream when a route bound one
    /// and nothing when it did not; the service decides per RPC what it requires.
    package struct Dependencies: Sendable {
        package let userAuthenticator: any Authenticator<String, UserIdentity>
        package let users: any <Organization>_Users_V1_UserService.ClientProtocol
        package let items: any <Organization>_Catalog_V1_ItemService.ClientProtocol

        package init(
            userAuthenticator: any Authenticator<String, UserIdentity>,
            users: any <Organization>_Users_V1_UserService.ClientProtocol,
            items: any <Organization>_Catalog_V1_ItemService.ClientProtocol
        ) {
            self.userAuthenticator = userAuthenticator
            self.users = users
            self.items = items
        }
    }

    private let dependencies: Dependencies

    package init(dependencies: Dependencies) {
        self.dependencies = dependencies
    }

    package func addRoutes(to group: RouterGroup<BasicRequestContext>) {
        let authenticationController = AuthenticationController(client: dependencies.users)
        let profileController = ProfileController(client: dependencies.users)
        let itemController = ItemController(client: dependencies.items)

        // Tier 1: no caller.
        group.get("health") { _, _ -> HTTPResponse.Status in .ok }
        authenticationController.addPublicRoutes(to: group.group("auth"))
        itemController.addPublicRoutes(to: group.group("items"))

        // Tier 2: a caller, if there is one. No UserSettingsMiddleware: the gateway has no database.
        let identified = group.group(context: IdentityRequestContext.self)
            .add(middleware: BearerAuthenticationMiddleware<IdentityRequestContext>(authenticator: dependencies.userAuthenticator))

        // Tier 3: a caller, required.
        let authenticated = identified.group().add(middleware: IsAuthenticatedMiddleware())
        profileController.addAuthenticatedRoutes(to: authenticated.group("profile"))
        itemController.addAuthenticatedRoutes(to: authenticated.group("items"))
    }
}
```

The root mounts it under the version prefix (`api.addRoutes(to: router.group("v1"))`); resource prefixes stay here and routes in the controllers.

## Composition root

A gateway's `serve` follows the building skill's section order — Configuration, Logging, Infrastructure, Composition, Router, Hummingbird, Lifecycle — with no gRPC section and no database. Under Infrastructure, build `JWTAuthenticator<UserIdentity>` over the public key through the EdDSA initializer `<Project>Authentication` adds, as the building skill's [identity reference](../../building-swift-services/references/identity-and-access.md) describes, and one `GRPCClient` per upstream: a required host and port, the stack's mTLS client factory and `ServiceConfig.defaults` from the [transport security factories](../../building-swift-services/references/composition.md#transport-security-factories), the gateway's connection config, and the propagating interceptor on that upstream's `<Entity>Service` descriptors alone:

```swift
// MARK: - Infrastructure
let tlsConfig = config.scoped(to: "tls")
// certificateReloader: primed from tlsConfig as the transport security factories describe
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
        config: .gateway,
        serviceConfig: .defaults
    ),
    interceptorPipeline: [
        .apply(propagation, to: .services([<Organization>_Users_V1_UserService.descriptor]))
    ]
)
```

`HTTP2ClientTransport.Posix.Config+Gateway.swift` keeps every upstream connection warm, so the first request after a quiet period does not wait for a new TLS handshake:

```swift
import GRPCNIOTransportHTTP2

extension HTTP2ClientTransport.Posix.Config {
    static var gateway: Self {
        .defaults {
            $0.connection.keepalive = .init(time: .seconds(300), timeout: .seconds(20), allowWithoutCalls: true)
        }
    }
}
```

The upstream servers must permit idle pings at that interval: with grpc-swift's default server policy, a ping with no call in flight counts as a strike and the server closes the connection. Each service's `HTTP2ServerTransport.Posix.Config` sets `$0.connection.keepalive.clientBehavior = .init(minPingIntervalWithoutCalls: .seconds(60), allowWithoutCalls: true)`.

Under Composition, wrap each client in its generated stub — `<Organization>_Users_V1_UserService.Client(wrapping: usersClient)` — and hand the stubs and the authenticator to `<Project>API.Dependencies`. Propagation forwards a token only when a principal is bound, so a tier-1 route calls the same stub anonymously, which is what the session-issuing RPCs expect; a caller's-own route sends no user id, because the forwarded token names the caller.

Under Router, add CORS where browsers call directly, `ErrorMiddleware`, and request logging to a router on `BasicRequestContext`, and mount `<Project>API(dependencies:)` under `v1`. Under Hummingbird, `ApplicationConfiguration(reader:)` scoped to `http.server` and the server-TLS builder from [surface.md](surface.md#composition): the gateway's own listener is client-facing and requires no client certificate, while its upstream clients keep mTLS. Under Lifecycle, the reloader, every client, and the application in one `ServiceGroup`:

```swift
let serviceGroup = ServiceGroup(
    services: [lokiProcessor, certificateReloader, usersClient, catalogClient, application],
    gracefulShutdownSignals: [.sigint, .sigterm],
    logger: logger
)
```

## Tests

Two suites, split by purpose. The router harness covers the tier matrix, conversions, and error mapping over mocked client protocols; one live loopback mTLS suite covers what only real connections prove.

**The router harness.** Compose the router as `serve` does, from the same router builder, over a `Dependencies.mocked` helper in which every client is unstubbed, so a suite overrides only the client it exercises and a route straying anywhere else fails loudly:

```swift
// Support/APIApplication.swift
import API
import Authentication
import Hummingbird
import HummingbirdTesting
import <Project>Authentication

extension <Project>API.Dependencies {
    static func mocked(
        authenticator: any Authenticator<String, UserIdentity>,
        users: MockUsersClient = MockUsersClient(),
        items: MockItemsClient = MockItemsClient()
    ) -> Self {
        .init(userAuthenticator: authenticator, users: users, items: items)
    }
}

func withApp<Value: Sendable>(
    _ dependencies: <Project>API.Dependencies,
    _ body: @Sendable (any TestClientProtocol) async throws -> Value
) async throws -> Value {
    let router = Router(context: BasicRequestContext.self)
    router.add(middleware: ErrorMiddleware())
    <Project>API(dependencies: dependencies).addRoutes(to: router.group("v1"))
    return try await Application(router: router).test(.router, body)
}
```

`TestTokens` holds a real `JWTIssuer<UserIdentity>` and `JWTAuthenticator<UserIdentity>` over one throwaway `EdDSA.PrivateKey(curve: .ed25519)`, with `userToken()`, `adminToken()`, and a signed token whose subject is not a user id.

A grpc-swift 2 generated `ClientProtocol` has one generic requirement per RPC, taking the serializer, deserializer, and response handler; a mock implements each by recording the request and answering its stub:

```swift
// Mocks/MockItemsClient.swift
import CatalogProtos
import GRPCCore
import SwiftProtobuf

private typealias ItemMessage = <Organization>_Catalog_V1_Item
private typealias GetItemRequest = <Organization>_Catalog_V1_GetItemRequest

struct MockItemsClient: <Organization>_Catalog_V1_ItemService.ClientProtocol {
    let recorder = Recorder()
    var getItemResult: Result<ItemMessage, RPCError>? = nil

    func getItem<Return: Sendable>(
        request: GRPCCore.ClientRequest<GetItemRequest>,
        serializer: some GRPCCore.MessageSerializer<GetItemRequest>,
        deserializer: some GRPCCore.MessageDeserializer<ItemMessage>,
        options: GRPCCore.CallOptions,
        onResponse handleResponse: @Sendable @escaping (GRPCCore.ClientResponse<ItemMessage>) async throws -> Return
    ) async throws -> Return {
        await recorder.record(request.message)
        return try await respond(getItemResult, handleResponse)
    }

    // One method of this shape per RPC of the service.
}
```

```swift
// Support/Responding.swift
import GRPCCore

/// Hands the stubbed message to the response handler, or throws the stubbed error as the transport would.
/// An unstubbed RPC throws `unimplemented`, so a route reaching an RPC its test did not expect fails with
/// a legible status instead of trapping.
func respond<Message: Sendable, Return: Sendable>(
    _ stub: Result<Message, RPCError>?,
    _ handleResponse: @Sendable (GRPCCore.ClientResponse<Message>) async throws -> Return
) async throws -> Return {
    guard let stub else {
        throw RPCError(code: .unimplemented, message: "This RPC is not stubbed.")
    }
    return try await handleResponse(GRPCCore.ClientResponse(message: try stub.get()))
}

/// Requests of every RPC in one ordered list; a test asks for the messages of the type it cares about.
actor Recorder {
    private(set) var all: [any Sendable] = []

    func record(_ message: any Sendable) {
        all.append(message)
    }

    func messages<Message>(of type: Message.Type = Message.self) -> [Message] {
        all.compactMap { $0 as? Message }
    }
}
```

Cover the tier matrix — a session-issuing route reaches its handler carrying an unverifiable bearer token, a protected route carrying the same token answers `401`, anonymous `401`, a non-administrator `403` on an administrative route — each controller's conversions, including a malformed upstream value answering an error rather than disappearing, that internal operations have no route (`/v1/internal/...` answers `404` with an administrator's token), and the `RPCError` problem mapping once, as a parameterized test over explicit code/status pairs. Assert that a caller's-own route sends no user id and that each route reaches the RPC it names.

**The live loopback mTLS suite.** One suite in `Upstreams/` runs the gateway against real upstreams on `127.0.0.1`, port `0`: a throwaway CA minted with `X509` and `Crypto` writes server and client pairs to temporary files; each fixture upstream is a `GRPCServer` with mTLS and the services' bearer interceptor over the same public key, registering representative methods that record the bearer metadata and the bound user; and the fixture hands back `Dependencies` whose clients are built as `serve` builds them — the mTLS factory with a `TimedCertificateReloader`, `config: .gateway`, and propagation on `<Entity>Service` descriptors — inside a `ServiceGroup`. It proves:

- A signed-in route forwards the caller's original token, and the receiver binds the same user id.
- A tier-1 route carrying an unverifiable token reaches its upstream with no authorization metadata.
- An `<Entity>InternalService` stub over the same `GRPCClient`, called with a principal bound, sends no token: propagation is scoped to `<Entity>Service` descriptors.
- A receiver verifying with a different key refuses a token the gateway accepted.

Observe connection and reload state with bounded polling instead of sleeping, and remove the temporary files in a `defer`. Generic TLS rejection and reload mechanics belong to the shared contract suites; see *Transport tests* in the building skill's [testing reference](../../building-swift-services/references/testing.md). What the services decide is their tests'.
