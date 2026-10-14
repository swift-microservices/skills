# The SwiftPM package

## Contents

- [Package initialization](#package-initialization)
- [Swift settings for packages and applications](#swift-settings-for-packages-and-applications)
- [Dependency baseline](#dependency-baseline)
- [Foundation dependencies and traits](#foundation-dependencies-and-traits)
- [Source tree of a module](#source-tree-of-a-module)
- [Source tree of a monolith](#source-tree-of-a-monolith)
- [Source tree of a service](#source-tree-of-a-service)
- [Manifest of a module's targets](#manifest-of-a-modules-targets)
- [Manifest of a monolith](#manifest-of-a-monolith)
- [Manifest of a service](#manifest-of-a-service)
- [Products](#products)

## Package initialization

Initialize the directory first:

```bash
swift package init --type executable
```

Then reshape the generated package. A monolith is initialized once and gains a module by adding that module's targets to the existing manifest; a service is one package per module; a gateway is its own package. Keep the Swift tools version, Swift language mode 6, the platform floor, and dependency versions aligned across the organization's repositories unless the user asks to upgrade.

## Swift settings for packages and applications

Use Swift tools 6.3, `swiftLanguageModes: [.v6]`, `platforms: [.macOS(.v15)]`, and one stored `swiftSettings` array enabling `ExistentialAny`, `MemberImportVisibility`, `InternalImportsByDefault`, and `NonisolatedNonsendingByDefault`, passed to every owned Swift target: library, executable, and test, the composition root and worker included. Server packages keep nonisolated default isolation. The settings, what each means, and the settled concurrency rules are the writing-swift-server-code skill's [swift-settings.md](../../writing-swift-server-code/references/swift-settings.md); the manifests below apply them.

## Dependency baseline

These are the packages the architecture is built on, with their version floors and the products each target takes from them. Use the newest compatible releases that support FoundationEssentials and the modern APIs the package needs, and keep floors aligned across the organization.

```swift
dependencies: [
    .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.8.2"),                    // ArgumentParser: the command tree
    .package(url: "https://github.com/apple/swift-async-algorithms.git", from: "1.1.5"),                  // AsyncAlgorithms: Postgres targets collect rows with Array(result)
    .package(url: "https://github.com/apple/swift-configuration.git", from: "1.2.0", traits: []),         // Configuration, EnvironmentVariablesProvider
    .package(url: "https://github.com/swift-server/swift-service-lifecycle.git", from: "2.12.0"),         // ServiceLifecycle (ServiceGroup), UnixSignals (gracefulShutdownSignals)
    .package(url: "https://github.com/apple/swift-log.git", from: "1.15.0"),                              // Logging: the facade, linked by every Core
    .package(url: "https://github.com/lovetodream/swift-log-loki.git", from: "2.0.1"),                    // LoggingLoki: the default log shipper, the executable only
    .package(url: "https://github.com/apple/swift-nio.git", from: "2.103.0"),                             // NIOCore, NIOFoundationEssentialsCompat: only when a target imports one directly
    .package(url: "https://github.com/hummingbird-project/postgres-migrations.git", from: "1.2.0"),       // PostgresMigrations
    .package(url: "https://github.com/vapor/postgres-nio.git", from: "1.33.1"),                           // PostgresNIO; 1.33.1 cancels a query against a silent server
    .package(url: "https://github.com/grpc/grpc-swift-2.git", from: "2.4.0"),                             // GRPCCore: with gRPC
    .package(url: "https://github.com/grpc/grpc-swift-nio-transport.git", from: "2.10.0"),                // GRPCNIOTransportHTTP2: with gRPC, or Temporal's mTLS transport
    .package(url: "https://github.com/grpc/grpc-swift-extras.git", from: "2.2.1"),                        // GRPCServiceLifecycle: with gRPC
    .package(url: "https://github.com/grpc/grpc-swift-protobuf.git", from: "2.4.0"),                      // GRPCProtobuf, GRPCProtobufGenerator: with in-package protos only
    .package(url: "https://github.com/apple/swift-protobuf.git", from: "1.32.0"),                         // SwiftProtobuf: with gRPC
    .package(url: "https://github.com/apple/swift-nio-extras.git", from: "1.35.1"),                       // NIOCertificateReloading: the executable; every listener serves TLS
    .package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "2.28.0", traits: ["ConfigurationSupport"]), // Hummingbird, HummingbirdTLS, HummingbirdTesting: with HTTP
    .package(url: "https://github.com/hummingbird-project/hummingbird-auth.git", from: "2.5.0"),          // HummingbirdAuth with HTTP; HummingbirdBcrypt only in a <Module>Bcrypt target
    .package(url: "https://github.com/apple/swift-openapi-generator.git", from: "1.13.0"),                // the OpenAPIGenerator plugin: with HTTP
    .package(url: "https://github.com/apple/swift-openapi-runtime.git", from: "1.12.1", traits: []),      // OpenAPIRuntime: with HTTP
    // .package(url: "https://github.com/vapor/vapor.git", from: "4.122.0"),                              // Vapor, VaporTesting: only when the HTTP surface is on Vapor
    .package(url: "https://github.com/apple/swift-temporal-sdk.git", from: "1.2.0"),                      // Temporal, TemporalTestKit: only with durable orchestration
    .package(url: "https://github.com/vapor/jwt-kit.git", from: "5.7.1"),                                 // JWTKit: the key types, in the executable
    .package(url: "https://github.com/swift-microservices/swift-operation-context.git", from: "0.1.0"),   // OperationContext: transport targets and the executable
    .package(url: "https://github.com/swift-microservices/swift-persistence.git", from: "0.2.0"),         // Persistence: Database<Scope>, linked by every Core
    .package(url: "https://github.com/swift-microservices/swift-persistence-postgres.git", from: "0.3.0"),// PersistencePostgres: PostgresDatabase, PostgresScope, PostgresSettings, PostgresClient.withClient
    .package(url: "https://github.com/swift-microservices/swift-authentication.git", from: "0.4.0"),      // Authentication: Principal (.identity), Authenticator; every transport target
    .package(url: "https://github.com/swift-microservices/swift-authentication-jwt.git", from: "0.3.2"),  // AuthenticationJWT: JWTAuthenticator and JWTIssuer over a JWTKeyCollection
    .package(url: "https://github.com/swift-microservices/swift-authentication-grpc.git", from: "0.5.0"), // AuthenticationGRPC: the bearer interceptors; with gRPC
    .package(url: "https://github.com/swift-microservices/swift-authentication-hummingbird.git", from: "0.4.0"), // AuthenticationHummingbird: the bearer middleware; with HTTP
    .package(url: "https://github.com/<organization>/<project>-core.git", from: "0.1.0"),                 // <Project>Authentication, <Project>Persistence, <Project>Testing; in-package targets in a one-package monolith
    .package(url: "https://github.com/<organization>/<project>-protos.git", from: "0.1.0"),               // <Module>Protos: with gRPC in microservices
    .package(url: "https://github.com/apple/swift-container-plugin.git", from: "1.4.0"),                  // build-container-image: only when the project builds images with it
    // With a <Module>GRPCTests loopback suite, the test certificates:
    .package(url: "https://github.com/apple/swift-certificates.git", from: "1.20.0"),                     // X509
    .package(url: "https://github.com/apple/swift-crypto.git", from: "4.0.0"),                            // Crypto
    .package(url: "https://github.com/apple/swift-asn1.git", from: "1.7.3"),                              // SwiftASN1
]
```

`swift-authentication-vapor` (`AuthenticationVapor`), `swift-openapi-hummingbird`, and `swift-openapi-vapor` join only on the paths the building-swift-http-surfaces skill names for them.

Declare only the direct products a target imports, and declare a package only when some target links one of its products or the project's build uses it as a command plugin; Xcode warns on a package no target uses. An HTTP-only package declares no grpc-swift, protobuf, or protos package; a gRPC-only package declares no Hummingbird or OpenAPI package. The container plugin is invoked from the package command line and is not attached to a source target.

Depend on organization packages by tagged URL, never by `.package(path:)`: a path dependency builds only where the sibling happens to be checked out, and silently builds against uncommitted contract changes. Publish and tag first, then pin `from:` the release containing what the package imports. Tag contract additions as the compatible-addition release the library labels require (`🔨 semver/patch` in 0.x, `🆕 semver/minor` after 1.0.0). A library package never commits `Package.resolved`; an executable package does. A published tag never moves; if an upstream tag was moved anyway, delete the stale fingerprint and re-resolve.

After renaming a target, delete `.build` in that package and every consumer, or the stale `.swiftmodule` keeps the old module name.

## Foundation dependencies and traits

Declare `swift-configuration` with `traits: []`, `hummingbird` with only the traits it uses (`["ConfigurationSupport"]` with its configuration integration, otherwise `[]`), and `swift-openapi-runtime` with `traits: []`; take ByteBuffer helpers from `NIOFoundationEssentialsCompat`. PostgresNIO and Vapor 4 link full Foundation upstream: a documented constraint, not a reason to drop them. Why, and how linkage is proved, is in the writing-swift-server-code skill's [foundation.md](../../writing-swift-server-code/references/foundation.md#dependency-traits-that-pull-in-foundation).

## Source tree of a module

A module's targets look the same in every shape. `<Module>` is the service name in a service.

```text
Sources/
  <Module>Core/
    <Features>/
      <Entity>.swift
      <Rule>Policy.swift
      Repository/
        <Entity>Repository.swift
        <Entity>RepositoryError.swift
        Commands/
          Create<Entity>Command.swift
      UseCases/
        Create<Entity>/
          Create<Entity>UseCase.swift
          Create<Entity>UseCaseError.swift
          Create<Entity>UseCaseInput.swift
          Create<Entity>UseCaseProtocol.swift
          Create<Entity>UseCaseScope.swift
    Ports/                                            # only a consumer of another module
      <Entity>Client.swift                            # the narrow port, its error, and the consumer's own value
    <Feature>/Activities/                             # only with Temporal
      <Feature>ActivityService.swift
      <Feature>ActivityServiceProtocol.swift
  <Module>Postgres/
    Scopes/
      Postgres<Module>Scope.swift
      Postgres<Module>InternalScope.swift             # only a module with tenant tables
      Postgres<Module>WorkerScope.swift               # only with Temporal
    Extensions/
      <Enum>+PostgresCodable.swift                    # a Core enum stored as text
    Migrations/
      Role/                                           # only a service: a monolith's roles live at the executable
        CreateServiceRole.swift
        CreateInternalRole.swift                      # only with tenant tables
        CreateWorkerRole.swift                        # only with Temporal
      <Entity>/
        Create<Entities>Table.swift
        Create<Entities>RLSPolicy.swift               # only a tenant table
    Repositories/
      <Entity>/
        Postgres<Entity>Repository.swift
    Statements/
      <Entity>/
        <Entity>+PostgresRow.swift                    # init(row:), shared by the entity's statements
        Create<Entity>Statement.swift
        List<Entities>Statement.swift
  <Module>HTTP/                                       # with HTTP
    openapi.yaml
    openapi-generator-config.yaml
    Controllers/
      <Entity>Controller.swift
    Schemas/
      Requests/
        Create<Entity>Request+Schema.swift
      Responses/
        <Entity>Response+Schema.swift
    Problems/
      Create<Entity>UseCaseError+HTTPProblemResponse.swift
    Contexts/                                         # only a service: a monolith's contexts live in <Project>HTTP
    Middlewares/ErrorMiddleware/                      # only a service, likewise
  <Module>GRPC/                                       # with gRPC
    Protos/<organization>/<module>/v1/<module>.proto  # only a monolith keeping its contracts in the package
    grpc-swift-proto-generator-config.json            # likewise
    <Features>/
      <Entity>Service.swift
      <Entity>InternalService.swift                   # one conformance per proto service the contract has
      Protobuf/
        <Entity>+Protobuf.swift
        Create<Entity>UseCaseInput+Protobuf.swift
    Clients/                                          # only a consumer of another service
      GRPC<Entity>Client.swift                        # the consumer adapter conforming to the Core port
  <Module>Workflows/                                  # only with Temporal
    <Feature>/
      <Feature>Workflow.swift
      <Feature>Activities.swift
      Temporal<Feature>WorkflowClient.swift
  <Module>Bcrypt/                                     # one target per provider SDK
    BcryptPasswordHasher.swift
Tests/
  <Module>CoreTests/
    Mocks/
      <Entity>UseCaseMocks.swift                      # actor repositories, the mock scope, makeSubject
      WithDatabase.swift
    Support/
      Values.swift                                    # UUID.user, UUID.missing, Date.reference
    <Entity>UseCaseTests.swift
  <Module>GRPCTests/                                  # with gRPC
    TLSFixtures.swift                                 # a throwaway CA and leaf pairs
    <Entity>ServiceFixtures.swift                     # the loopback server and client
    <Module>GRPCTests.swift
  <Module>WorkflowsTests/                             # only with Temporal
```

Use plural feature folders such as `Items`, then group repository and use-case artifacts within that feature. Do not create top-level `Entities`, `UseCases`, or `Repositories` buckets in Core. In Postgres, group by technical responsibility and then entity.

In GRPC, keep the generated-service conformances at the feature root, one file per proto service, and every conversion in that feature's single `Protobuf/` directory. In HTTP, keep one controller per resource and the conversions in `Schemas/`; the HTTP target's contents are the building-swift-http-surfaces skill's [surface reference](../../building-swift-http-surfaces/references/surface.md).

When Temporal is required, keep its SDK and every macro-decorated Workflow and Activity in `<Module>Workflows`; Core defines the workflow-client and Activity-service protocols and the workflow state and result values.

## Source tree of a monolith

```text
Package.swift
Makefile
.env.example
compose.yaml
Sources/
  <Project>/
    <Project>.swift
    Configuration/
      PostgresConfiguration.swift
      InMemoryProvider+ApplicationDefaults.swift
      LokiLogProcessorConfiguration+ConfigReader.swift
      EdDSA.PrivateKey+ConfigReader.swift             # the monolith issues tokens; it verifies with the key's public half
      HMACKey+ConfigReader.swift                      # instead, when the project records a symmetric key
      TimedCertificateReloader.Configuration+ConfigReader.swift          # with gRPC or Temporal
      HTTP2ServerTransport.Posix.Config+ConfigReader.swift               # with gRPC
      HTTP2ServerTransport.Posix.TransportSecurity+ConfigReader.swift    # with gRPC
      HTTP2ClientTransport.Posix.TransportSecurity+ConfigReader.swift    # only when it dials another process or Temporal
    Ports/
      <Producer><Port>.swift                          # one adapter per cross-module port, such as UsersAccountClient
    Database/
      Migrations.swift                                # every migration in applied order, usually roles first
      Role/
        CreateServiceRole.swift
        CreateInternalRole.swift                      # only when any module has tenant tables
        CreateWorkerRole.swift                        # only with Temporal
    Serve/
      Serve.swift
    Worker/                                           # only with Temporal
      Worker.swift
      Run.swift
  <Project>Authentication/                            # the org layer, in-package until a second package needs it
    UserIdentity.swift
    UserRole.swift
    OperationContext+User.swift                       # OperationContext.user and the .user metadata provider
    JWT+EdDSA.swift
  <Project>Persistence/                               # only when any module has tenant tables
    PostgresSettings+User.swift
    UserSettingsInterceptor.swift                     # with gRPC
    UserSettingsMiddleware.swift                      # with HTTP
  <Project>Testing/
    MockDatabase.swift
    MockUserAuthenticator.swift
  <Project>HTTP/                                      # with HTTP
    Contexts/
      IdentityRequestContext.swift
      AdminRequestContext.swift
    Middlewares/
      ErrorMiddleware/
        ErrorMiddleware.swift
        Problem/
          Problem.swift
          HTTPProblemResponse.swift
          Conformances/
            HTTPError+HTTPProblemResponse.swift
  CatalogCore/ CatalogPostgres/ CatalogHTTP/ CatalogGRPC/      # one module
  UsersCore/ UsersPostgres/ UsersHTTP/ UsersGRPC/ UsersBcrypt/ # another
Tests/
  CatalogCoreTests/
  UsersCoreTests/
  UsersGRPCTests/                                     # with gRPC: one loopback suite per module that serves RPCs
  CatalogWorkflowsTests/                              # only with Temporal, per module with workflows
```

The role migrations live at the executable because roles belong to the process and no module owns them. `<Project>HTTP` holds only what every `<Module>HTTP` shares; it never holds a controller. `Ports/` holds only adapters that convert one module's use case into another module's port ([core.md](core.md#ports-to-other-modules)).

`<Project>Authentication`, `<Project>Persistence`, and `<Project>Testing` are what `<project>-core` would hold, as in-package targets with `package` access; their contents are the building-swift-server-libraries skill's [organization-layer.md](../../building-swift-server-libraries/references/organization-layer.md). The day a second package needs them, they move to a tagged `<project>-core` unchanged except for `public` access, the same rule as in-package protos, and the manifest swaps each target name for the product.

## Source tree of a service

```text
Package.swift
Makefile
.env.example
compose.yaml
Sources/
  <Service>/
    <Service>.swift
    Configuration/
      PostgresConfiguration.swift
      InMemoryProvider+ApplicationDefaults.swift
      LokiLogProcessorConfiguration+ConfigReader.swift
      EdDSA.PublicKey+ConfigReader.swift
      EdDSA.PrivateKey+ConfigReader.swift             # only the authenticating service
      TimedCertificateReloader.Configuration+ConfigReader.swift
      HTTP2ServerTransport.Posix.Config+ConfigReader.swift
      HTTP2ServerTransport.Posix.TransportSecurity+ConfigReader.swift
      HTTP2ClientTransport.Posix.TransportSecurity+ConfigReader.swift    # only a consumer of another service, or Temporal
    Database/
      Migrations.swift
    Serve/
      Serve.swift
    Worker/                                           # only with Temporal
      Worker.swift                                    # the `worker` command group
      Run.swift                                       # `worker run`: the worker's composition root
  <Service>Core/ <Service>Postgres/ <Service>GRPC/    # the module, as above; <Service>HTTP with HTTP
Tests/
  <Service>CoreTests/
  <Service>GRPCTests/
  <Service>WorkflowsTests/                            # only with Temporal
```

The service's `<Service>Postgres/Migrations/Role/` holds the role migrations, and `<Service>HTTP`, when it exists, holds its own `Contexts/` and `Middlewares/`.

## Manifest of a module's targets

The same block in every shape; the executable that links them differs. In a one-package monolith, replace each `.product(name: "<Project>X", package: "<project>-core")` with the in-package target `"<Project>X"`.

```swift
.target(
    name: "<Module>Core",
    dependencies: [
        // The transaction boundary, the identities, and the swift-log facade; nothing that talks to a network.
        .product(name: "Persistence", package: "swift-persistence"),
        .product(name: "<Project>Authentication", package: "<project>-core"),
        .product(name: "Logging", package: "swift-log"),
    ],
    swiftSettings: swiftSettings
),
.target(
    name: "<Module>Postgres",
    dependencies: [
        "<Module>Core",
        .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
        .product(name: "Logging", package: "swift-log"),
        .product(name: "PostgresMigrations", package: "postgres-migrations"),
        .product(name: "PostgresNIO", package: "postgres-nio"),
        .product(name: "PersistencePostgres", package: "swift-persistence-postgres"),
    ],
    swiftSettings: swiftSettings
),
.target(
    name: "<Module>HTTP",                                   // with HTTP
    dependencies: [
        "<Module>Core",
        "<Project>HTTP",                                    // a monolith; a service holds the contexts itself
        .product(name: "Hummingbird", package: "hummingbird"),
        .product(name: "HummingbirdAuth", package: "hummingbird-auth"),
        .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
        .product(name: "<Project>Authentication", package: "<project>-core"),
        .product(name: "Logging", package: "swift-log"),
    ],
    swiftSettings: swiftSettings,
    plugins: [
        .plugin(name: "OpenAPIGenerator", package: "swift-openapi-generator")
    ]
),
.target(
    name: "<Module>GRPC",                                   // with gRPC, contracts from <project>-protos
    dependencies: [
        "<Module>Core",
        .product(name: "Authentication", package: "swift-authentication"),     // Principal.identity in requireUser()
        .product(name: "GRPCCore", package: "grpc-swift-2"),
        .product(name: "OperationContext", package: "swift-operation-context"),
        .product(name: "SwiftProtobuf", package: "swift-protobuf"),
        .product(name: "<Project>Authentication", package: "<project>-core"),
        .product(name: "<Module>Protos", package: "<project>-protos"),         // the generated code links GRPCProtobuf itself
    ],
    swiftSettings: swiftSettings
),
.target(
    name: "<Module>Workflows",                              // only with Temporal
    dependencies: [
        "<Module>Core",
        .product(name: "Temporal", package: "swift-temporal-sdk"),
    ],
    swiftSettings: swiftSettings
),
.target(
    name: "<Module>Bcrypt",                                 // one adapter target per provider SDK
    dependencies: [
        "<Module>Core",
        .product(name: "HummingbirdBcrypt", package: "hummingbird-auth"),
    ],
    swiftSettings: swiftSettings
),
.testTarget(
    name: "<Module>CoreTests",
    dependencies: [
        "<Module>Core",
        .product(name: "Logging", package: "swift-log"),
        .product(name: "<Project>Authentication", package: "<project>-core"),
        .product(name: "<Project>Testing", package: "<project>-core"),
    ],
    swiftSettings: swiftSettings
),
.testTarget(
    name: "<Module>GRPCTests",                              // with gRPC: handler tests and the loopback TLS suite
    dependencies: [
        "<Module>Core",
        "<Module>GRPC",
        .product(name: "AuthenticationGRPC", package: "swift-authentication-grpc"),
        .product(name: "AuthenticationJWT", package: "swift-authentication-jwt"),
        .product(name: "Crypto", package: "swift-crypto"),
        .product(name: "GRPCCore", package: "grpc-swift-2"),
        .product(name: "GRPCNIOTransportHTTP2", package: "grpc-swift-nio-transport"),
        .product(name: "GRPCServiceLifecycle", package: "grpc-swift-extras"),
        .product(name: "JWTKit", package: "jwt-kit"),
        .product(name: "Logging", package: "swift-log"),
        .product(name: "NIOCertificateReloading", package: "swift-nio-extras"),
        .product(name: "ServiceLifecycle", package: "swift-service-lifecycle"),
        .product(name: "SwiftASN1", package: "swift-asn1"),
        .product(name: "SwiftProtobuf", package: "swift-protobuf"),
        .product(name: "X509", package: "swift-certificates"),
        .product(name: "<Project>Authentication", package: "<project>-core"),
        .product(name: "<Project>Persistence", package: "<project>-core"),     // only with tenant tables
        .product(name: "<Project>Testing", package: "<project>-core"),
        .product(name: "<Module>Protos", package: "<project>-protos"),         // not with in-package protos
    ],
    swiftSettings: swiftSettings
),
// .testTarget(name: "<Module>WorkflowsTests", …)          // only with Temporal: see the orchestrating-temporal-workflows skill
```

A `<Module>GRPC` that consumes another service adds that service's `<Producer>Protos` product for its client adapter and nothing else; a `<Module>Core` never adds a protos product.

A gRPC monolith keeps its contracts in the package (see [grpc-and-protos.md](grpc-and-protos.md#canonical-proto-package)): it drops the `<Module>Protos` product, puts the files under `Sources/<Module>GRPC/Protos/`, and generates in place with `package` access:

```swift
.target(
    name: "CatalogGRPC",
    dependencies: [
        "CatalogCore",
        "<Project>Authentication",
        .product(name: "Authentication", package: "swift-authentication"),
        .product(name: "GRPCCore", package: "grpc-swift-2"),
        .product(name: "GRPCProtobuf", package: "grpc-swift-protobuf"),
        .product(name: "OperationContext", package: "swift-operation-context"),
        .product(name: "SwiftProtobuf", package: "swift-protobuf"),
    ],
    swiftSettings: swiftSettings,
    plugins: [.plugin(name: "GRPCProtobufGenerator", package: "grpc-swift-protobuf")]
),
```

The day a second package needs the contract, the `Protos/` folder moves into `<project>-protos` as that module's target and the plugin line goes with it.

## Manifest of a monolith

The module blocks above, once per module, plus the org-layer targets, the shared HTTP target, and one executable:

```swift
.target(
    name: "<Project>Authentication",                        // UserIdentity, UserRole, OperationContext.user, .user, the EdDSA conveniences
    dependencies: [
        .product(name: "Authentication", package: "swift-authentication"),
        .product(name: "AuthenticationJWT", package: "swift-authentication-jwt"),
        .product(name: "JWTKit", package: "jwt-kit"),
        .product(name: "Logging", package: "swift-log"),
        .product(name: "OperationContext", package: "swift-operation-context"),
    ],
    swiftSettings: swiftSettings
),
.target(
    name: "<Project>Persistence",                           // only with tenant tables: PostgresSettings.user(_:) and what binds it
    dependencies: [
        "<Project>Authentication",
        .product(name: "Authentication", package: "swift-authentication"),
        .product(name: "GRPCCore", package: "grpc-swift-2"),                         // with gRPC: UserSettingsInterceptor
        .product(name: "Hummingbird", package: "hummingbird"),                       // with HTTP: UserSettingsMiddleware
        .product(name: "OperationContext", package: "swift-operation-context"),
        .product(name: "PersistencePostgres", package: "swift-persistence-postgres"),
    ],
    swiftSettings: swiftSettings
),
.target(
    name: "<Project>Testing",                               // MockDatabase, MockUserAuthenticator: test targets only
    dependencies: [
        "<Project>Authentication",
        .product(name: "Authentication", package: "swift-authentication"),
        .product(name: "Persistence", package: "swift-persistence"),
    ],
    swiftSettings: swiftSettings
),
.target(
    name: "<Project>HTTP",                                  // with HTTP
    dependencies: [
        "<Project>Authentication",
        .product(name: "Hummingbird", package: "hummingbird"),
        .product(name: "HummingbirdAuth", package: "hummingbird-auth"),
    ],
    swiftSettings: swiftSettings
),
.executableTarget(
    name: "<Project>",
    dependencies: [
        "CatalogCore", "CatalogPostgres", "CatalogHTTP", "CatalogGRPC",
        "UsersCore", "UsersPostgres", "UsersHTTP", "UsersGRPC", "UsersBcrypt",
        "<Project>Authentication",
        "<Project>Persistence",                                                      // only when any module has tenant tables
        "<Project>HTTP",                                                             // with HTTP
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
        .product(name: "AuthenticationJWT", package: "swift-authentication-jwt"),
        .product(name: "Configuration", package: "swift-configuration"),
        .product(name: "Hummingbird", package: "hummingbird"),                       // with HTTP
        .product(name: "HummingbirdAuth", package: "hummingbird-auth"),              // with HTTP
        .product(name: "HummingbirdTLS", package: "hummingbird"),                    // with HTTP: the listener's TLS
        .product(name: "AuthenticationHummingbird", package: "swift-authentication-hummingbird"), // with HTTP
        .product(name: "GRPCCore", package: "grpc-swift-2"),                         // with gRPC
        .product(name: "GRPCNIOTransportHTTP2", package: "grpc-swift-nio-transport"), // with gRPC or Temporal
        .product(name: "GRPCServiceLifecycle", package: "grpc-swift-extras"),        // with gRPC
        .product(name: "AuthenticationGRPC", package: "swift-authentication-grpc"),  // with gRPC
        .product(name: "NIOCertificateReloading", package: "swift-nio-extras"),      // every listener and client
        .product(name: "JWTKit", package: "jwt-kit"),
        .product(name: "Logging", package: "swift-log"),
        .product(name: "LoggingLoki", package: "swift-log-loki"),
        .product(name: "PersistencePostgres", package: "swift-persistence-postgres"),
        .product(name: "PostgresMigrations", package: "postgres-migrations"),
        .product(name: "PostgresNIO", package: "postgres-nio"),
        .product(name: "ServiceLifecycle", package: "swift-service-lifecycle"),
        .product(name: "UnixSignals", package: "swift-service-lifecycle"),
        .product(name: "Temporal", package: "swift-temporal-sdk"),                   // only with Temporal
    ],
    swiftSettings: swiftSettings
),
```

The executable links every module's targets and is the only target that does. A module's targets never appear in another module's dependency list. The proto descriptors the interceptor pipeline names come from each `<Module>GRPC`, because the contracts are generated there.

## Manifest of a service

The module blocks above, once, plus one executable:

```swift
.executableTarget(
    name: "<Service>",
    dependencies: [
        "<Service>Core",
        "<Service>Postgres",
        "<Service>GRPC",                                    // with gRPC
        "<Service>HTTP",                                    // with HTTP
        "<Service>Workflows",                               // only with Temporal: serve starts workflows, worker runs them
        .product(name: "<Service>Protos", package: "<project>-protos"),               // with gRPC: the descriptors the interceptors name
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
        .product(name: "Configuration", package: "swift-configuration"),
        .product(name: "GRPCCore", package: "grpc-swift-2"),                         // with gRPC
        .product(name: "GRPCNIOTransportHTTP2", package: "grpc-swift-nio-transport"), // with gRPC or Temporal
        .product(name: "GRPCServiceLifecycle", package: "grpc-swift-extras"),        // with gRPC
        .product(name: "AuthenticationGRPC", package: "swift-authentication-grpc"),  // with gRPC
        .product(name: "NIOCertificateReloading", package: "swift-nio-extras"),      // every listener and client
        .product(name: "Hummingbird", package: "hummingbird"),                       // with HTTP
        .product(name: "HummingbirdAuth", package: "hummingbird-auth"),              // with HTTP
        .product(name: "HummingbirdTLS", package: "hummingbird"),                    // with HTTP: the listener's TLS
        .product(name: "AuthenticationHummingbird", package: "swift-authentication-hummingbird"), // with HTTP
        .product(name: "AuthenticationJWT", package: "swift-authentication-jwt"),
        .product(name: "<Project>Authentication", package: "<project>-core"),
        .product(name: "<Project>Persistence", package: "<project>-core"),           // only with tenant tables
        .product(name: "JWTKit", package: "jwt-kit"),
        .product(name: "Logging", package: "swift-log"),
        .product(name: "LoggingLoki", package: "swift-log-loki"),
        .product(name: "PersistencePostgres", package: "swift-persistence-postgres"),
        .product(name: "PostgresMigrations", package: "postgres-migrations"),
        .product(name: "PostgresNIO", package: "postgres-nio"),
        .product(name: "ServiceLifecycle", package: "swift-service-lifecycle"),
        .product(name: "UnixSignals", package: "swift-service-lifecycle"),           // .sigint and .sigterm
        .product(name: "Temporal", package: "swift-temporal-sdk"),                   // only with Temporal
    ],
    swiftSettings: swiftSettings
),
```

Include a direct product dependency in every target that imports its module, as `MemberImportVisibility` requires. The executable, not the feature target, needs `GRPCNIOTransportHTTP2` because it constructs the transport, and `AuthenticationHummingbird` because it builds the middleware. Remove any dependency a target does not import.

## Products

Do not expose internal library products. The executable is the package's one product:

```swift
products: [
    .executable(name: "<executable>", targets: ["<Project>"]),   // a monolith or a gateway
    .executable(name: "<service>", targets: ["<Service>"]),      // a service
]
```

Internal targets communicate through `package` declarations. The Temporal worker is a subcommand of this executable, not a second product: one image with two process types is simpler to build, publish, and deploy than two images that must move together, and what the worker must not do, open the server or read the verifying key, is a property of its command.

Close every manifest with `swiftLanguageModes: [.v6]`.
