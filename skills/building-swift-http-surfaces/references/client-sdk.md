# The client SDK

## Contents

- [The package](#the-package)
- [The document](#the-document)
- [Generator configuration](#generator-configuration)
- [Manifest](#manifest)
- [Problem](#problem)
- [Token authentication](#token-authentication)
- [The client](#the-client)
- [Tests and CI](#tests-and-ci)

The library apps use to call a surface: generated from the surface's OpenAPI document, with token sign-in and refresh from swift-openapi-token-authentication. It is a library package, so its packaging, releases, and documentation follow the building-swift-server-libraries skill; this file holds what is particular to a generated client.

## The package

Name the package `<organization>-sdk`, with one product and target, `<Project>SDK`. It serves apps on Apple platforms beside macOS, and tooling on Linux:

```text
<organization>-sdk
├── Package.swift
└── Sources/
    └── <Project>SDK/
        ├── openapi.yaml                       # the gateway's document, synced
        ├── openapi-generator-config.yaml
        ├── Problem.swift
        ├── <Project>Client.swift              # typed wrappers over the generated Client
        ├── <Project>Client+URLSession.swift   # under the OpenAPIURLSession trait
        └── Authentication/
            ├── <Project>Credentials.swift
            ├── <Project>AuthenticationClient.swift
            ├── <Project>AuthenticationClient+URLSession.swift
            ├── AuthenticationResponse+<Project>.swift
            └── BearerTokenMiddleware.swift
```

## The document

The SDK generates from a copy of the gateway's `Sources/API/openapi.yaml` (or the one surface's document) kept at `Sources/<Project>SDK/openapi.yaml`, where the generator plugin looks. Sync it when the gateway releases a contract change, in a commit that names the gateway version, and release the SDK after it. Never reach a document outside the target with `resources: [.copy("../../openapi.yaml")]`: the path escapes the target, and the copy ships the document as a bundle resource every app then carries. The document must already be a client contract — operation ids, a `security` entry per operation, a `default` problem response, `servers` with the version path ([surface.md](surface.md#the-document-as-a-client-contract)).

## Generator configuration

```yaml
generate:
  - types
  - client
accessModifier: public
namingStrategy: idiomatic
typeOverrides:
  schemas:
    Problem: <Project>SDK.Problem
    UUID: Foundation.UUID
nameOverrides:
  UUID: UUID
additionalImports:
  - struct Foundation.UUID
```

`public` because apps call the generated `Client` and schemas directly. The `Problem` override replaces the generated schema with the hand-written public `Problem` below, so a problem response decodes into a type the SDK can throw; the module-qualified name keeps it from resolving to the generated `Components.Schemas.Problem` it replaces.

## Manifest

```swift
// swift-tools-version: 6.3
import PackageDescription

let swiftSettings: [SwiftSetting] = [
    .enableUpcomingFeature("ExistentialAny"),
    .enableUpcomingFeature("MemberImportVisibility"),
    .enableUpcomingFeature("InternalImportsByDefault"),
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
]

let package = Package(
    name: "<organization>-sdk",
    platforms: [
        .macOS(.v15),
        .iOS(.v18),
        .macCatalyst(.v18),
        .tvOS(.v18),
        .watchOS(.v11),
        .visionOS(.v2),
    ],
    products: [
        .library(name: "<Project>SDK", targets: ["<Project>SDK"])
    ],
    traits: [
        .trait(name: "OpenAPIURLSession", description: "URLSession-backed initializers for the clients."),
        .default(enabledTraits: ["OpenAPIURLSession"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-openapi-generator.git", from: "1.13.0"),
        .package(url: "https://github.com/apple/swift-openapi-runtime.git", from: "1.12.1", traits: []),
        .package(url: "https://github.com/apple/swift-openapi-urlsession.git", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-http-types.git", from: "1.0.0"),
        .package(url: "https://github.com/swift-microservices/swift-openapi-token-authentication.git", from: "0.2.2"),
    ],
    targets: [
        .target(
            name: "<Project>SDK",
            dependencies: [
                .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
                .product(name: "HTTPTypes", package: "swift-http-types"),
                .product(name: "OpenAPITokenAuthentication", package: "swift-openapi-token-authentication"),
                .product(
                    name: "OpenAPIURLSession",
                    package: "swift-openapi-urlsession",
                    condition: .when(traits: ["OpenAPIURLSession"])
                ),
            ],
            swiftSettings: swiftSettings,
            plugins: [
                .plugin(name: "OpenAPIGenerator", package: "swift-openapi-generator")
            ]
        )
    ],
    swiftLanguageModes: [.v6]
)
```

The platform floors are at least swift-openapi-token-authentication's. The `OpenAPIURLSession` trait is on by default, so an app gets URLSession initializers with no configuration; a consumer with its own `ClientTransport` (AsyncHTTPClient on a server, a test double) declares the package with `traits: []`, and nothing that names `URLSession` is compiled or linked. Guard every URLSession file with `#if OpenAPIURLSession`. The generated code imports full Foundation in both configurations; record that in `AGENTS.md` rather than claiming the trait-disabled build is Foundation-free.

## Problem

```swift
#if canImport(FoundationEssentials)
public import FoundationEssentials
#else
public import Foundation
#endif

/// An RFC 9457 problem details response.
public struct Problem: Codable, Hashable, Sendable, Error {
    public let type: String
    public let title: String
    public let status: Int
    public let detail: String?
    public let instance: String?

    public init(type: String, title: String, status: Int, detail: String? = nil, instance: String? = nil) {
        self.type = type
        self.title = title
        self.status = status
        self.detail = detail
        self.instance = instance
    }
}
```

Generated schema types must be `Codable`, `Hashable`, and `Sendable`, so an override must be too; `Error` lets the SDK throw it.

## Token authentication

swift-openapi-token-authentication's `AuthenticationSession` serializes sign-in and refresh and shares in-flight work; the SDK supplies three things.

The issued tokens: conform the generated sign-in response to `AuthenticationResponse`, mapping its fields onto `accessToken`, `accessTokenExpiration`, `refreshToken`, and `refreshTokenExpiration`:

```swift
public import OpenAPITokenAuthentication

#if canImport(FoundationEssentials)
public import FoundationEssentials
#else
public import Foundation
#endif

extension Components.Schemas.AuthenticationResponse: AuthenticationResponse {
    public var accessTokenExpiration: Date { accessTokenExpiresAt }
    public var refreshTokenExpiration: Date { refreshTokenExpiresAt }
}
```

The sign-in and refresh calls: an `AuthenticationClient` whose generated `Client`s carry no `AuthenticationMiddleware` — a refresh routed through the session's own middleware would wait on itself. Classify only rejections: a `401` on sign-in is `.invalidCredentials`, a `401` on refresh is `.invalidRefreshToken`, and every other error — another problem status, a transport failure, a decoding error — propagates unchanged. The session clears stored credentials only on a classified rejection, so wrapping a network failure as a rejection signs the user out whenever the connection drops:

```swift
public import OpenAPIRuntime
public import OpenAPITokenAuthentication

#if canImport(FoundationEssentials)
public import FoundationEssentials
#else
public import Foundation
#endif

public struct <Project>AuthenticationClient: AuthenticationClient {
    private let serverURL: URL
    private let transport: any ClientTransport

    public init(serverURL: URL, transport: any ClientTransport) {
        self.serverURL = serverURL
        self.transport = transport
    }

    public func authenticate(credentials: <Project>Credentials) async throws -> Components.Schemas.AuthenticationResponse {
        let client = Client(serverURL: serverURL, transport: transport)
        let body = Components.Schemas.SignInRequest(email: credentials.email, password: credentials.password)
        switch try await client.signIn(body: .json(body)) {
        case .ok(let ok):
            return try ok.body.json
        case .default(let statusCode, let response):
            let problem = try response.body.applicationProblemJson
            guard statusCode == 401 else { throw problem }
            throw AuthenticationClientError(.invalidCredentials, underlyingError: problem)
        }
    }

    public func refreshAuthentication(refreshToken: String) async throws -> Components.Schemas.AuthenticationResponse {
        let client = Client(serverURL: serverURL, transport: transport, middlewares: [BearerTokenMiddleware(token: refreshToken)])
        switch try await client.refreshSession() {
        case .ok(let ok):
            return try ok.body.json
        case .default(let statusCode, let response):
            let problem = try response.body.applicationProblemJson
            guard statusCode == 401 else { throw problem }
            throw AuthenticationClientError(.invalidRefreshToken, underlyingError: problem)
        }
    }
}
```

`<Project>Credentials` is a public `Sendable` value — an email and password here, an enum when the API offers several sign-in methods. `BearerTokenMiddleware` is an internal `ClientMiddleware` that sets `Authorization: Bearer <token>` on the refresh request, which the generator does not do for a security scheme.

The storage: apps supply an `AuthenticationStorage` — a Keychain-backed one on Apple platforms — and the SDK ships none beyond the package's `InMemoryAuthenticationStorage`. One `AuthenticationSession` per account, shared by every client that acts as it. Apps import `OpenAPITokenAuthentication` beside the SDK for the session and storage types.

## The client

`<Project>Client` wraps the generated `Client` twice over one transport: through `AuthenticationMiddleware(session:)` for operations whose `security` requires a bearer token, and without middleware for `security: []` operations, so an anonymous call never waits for, or fails on, a sign-in. An identifying-tier operation (`security: [{}, {bearerAuth: []}]`) uses a third client with `AuthenticationMiddleware(session:policy: .ifAvailable)`, which sends the token when there is one and the request unchanged when the session needs a sign-in. Each wrapper returns the decoded body and throws the `Problem` of a `default` response:

```swift
public func getProfile() async throws -> Components.Schemas.UserResponse {
    switch try await authenticated.getProfile() {
    case .ok(let ok):
        return try ok.body.json
    case .default(_, let response):
        throw try response.body.applicationProblemJson
    }
}
```

The URLSession initializers, in `<Project>Client+URLSession.swift` under `#if OpenAPIURLSession`, build `URLSessionTransport(configuration: .init(session: session))` and call the transport initializer; `URLSession` comes from `FoundationNetworking` on Linux.

## Tests and CI

A consumer fixture is required: a package in `.github/Fixtures/Consumer` that depends on the checkout by path and imports the generated client, schemas, and hand-written types, built with the default trait and with `--disable-default-traits`. It alone proves the public generated API and both trait configurations compile for a downstream package. Runtime tests are written only for hand-written behavior that decides something — the authentication client's status classification and propagation — with swift-testing over a stub `ClientTransport`, no network; generated wrappers get none, and no placeholder test target exists to fit a profile.

CI is the library profile's generated-SDK variant: a build matrix plus the consumer fixture in both trait configurations ([library-ci.md](../../delivering-swift-services/references/library-ci.md#capability-exceptions)), with `swift test` in the matrix when runtime tests exist.
