# The SwiftPM package

## Contents

- Package initialization
- Dependency baseline
- Source tree of a module
- Source tree of a monolith
- Source tree of a service
- Source tree of a gateway
- Manifest of a module's targets
- Manifest of a monolith
- Manifest of a service
- Manifest of a gateway
- Products

## Package initialization

Initialize the directory first:

```bash
swift package init --type executable
```

Then reshape the generated package. A monolith is initialized once and gains a module by adding that module's targets to the existing manifest; a service is one package per module; a gateway is its own package. Keep the Swift tools version, Swift language mode 6, the platform floor, and dependency versions aligned across the organization's repositories unless the user asks to upgrade.

## Dependency baseline

These are the packages the architecture is built on. The versions are a floor from when this skill was last revised, not an instruction to downgrade a repository that already uses compatible newer releases; align with the organization's other packages first, then with the newest compatible release.

| Package | Baseline | Products/purpose |
| --- | --- | --- |
| `swift-argument-parser` | `1.8.2` | `ArgumentParser` for the command tree |
| `swift-configuration` | `1.2.0` | `Configuration` and `EnvironmentVariablesProvider` |
| `swift-service-lifecycle` | `2.11.0` | `ServiceLifecycle` and `ServiceGroup` |
| `swift-log` | `1.15.0` | `Logging` facade (also linked by every Core so use cases log domain events) |
| `swift-log-loki` | `2.0.0` | `LoggingLoki`: the default in-process log shipper; any `LogHandler` the deployment prefers may take its place |
| `swift-nio` | `2.65.0` | `NIOFoundationCompat`, declared on an executable that links `LoggingLoki` but not PostgresNIO (a gateway); swift-log-loki 2.0.0 omits it |
| `postgres-migrations` | `1.2.0` | `PostgresMigrations` |
| `postgres-nio` | `1.33.1` | `PostgresNIO`, `PostgresClient`, prepared statements, transactions |
| `grpc-swift-2` | `2.4.0` | `GRPCCore`, `GRPCClient`, `GRPCServer`: with gRPC |
| `grpc-swift-nio-transport` | `2.9.1` | `GRPCNIOTransportHTTP2`: with gRPC |
| `grpc-swift-extras` | `2.2.0` | `GRPCServiceLifecycle` adapters: with gRPC |
| `grpc-swift-protobuf` | `2.4.0` | `GRPCProtobuf` and `GRPCProtobufGenerator`: with gRPC |
| `swift-protobuf` | `1.32.0` | `SwiftProtobuf` messages and well-known types: with gRPC |
| `hummingbird` | `2.26.0` | `Hummingbird` for the HTTP targets and the executable; `HummingbirdTesting` for HTTP tests |
| `hummingbird-auth` | `2.2.0` | `HummingbirdAuth` for `AuthRequestContext` and `IsAuthenticatedMiddleware`; `HummingbirdBcrypt` only in a `<Module>Bcrypt` adapter target |
| `swift-openapi-generator` | `1.13.0` | The `OpenAPIGenerator` plugin on every HTTP target that owns a document |
| `swift-openapi-runtime` | `1.12.0` | `OpenAPIRuntime` beside the generated types |
| `swift-openapi-hummingbird` | current | `OpenAPIHummingbird`, only with generated server stubs (the alternative in *http.md*); not linked by the types-only default |
| `swift-openapi-vapor` | current | `OpenAPIVapor`, the same for a Vapor surface |
| `vapor` | `4.122.0` | `Vapor`, only when the HTTP surface is on Vapor instead of Hummingbird; `VaporTesting` for its tests |
| `swift-temporal-sdk` | `1.0.0` | `Temporal`, only with durable orchestration |
| `jwt-kit` | `"5.3.0"..<"5.7.0"` | `JWTKit`: the executable, for the EdDSA key types; the pin's reason is in identity-and-access.md |
| `swift-service-context` | `1.3.0` | `ServiceContextModule`, wherever `ServiceContext.current` is read: the transport targets and the executable |
| `swift-persistence` | `0.1.0` | `Persistence`: `Database<Scope>`, linked by every Core |
| `swift-persistence-postgres` | `0.1.0` | `PersistencePostgres`: `PostgresDatabase`, `PostgresScope`, `PostgresSettings`, `PostgresClient.withClient` |
| `swift-authentication` | `0.1.0` | `Authentication`: the `Authenticator` protocol an HTTP target names to take any verifier |
| `swift-authentication-jwt` | `0.1.0` | `AuthenticationJWT`: `JWTAuthenticator<UserIdentity>` in the executable, `JWTIssuer<UserIdentity>` in the authenticating module |
| `swift-authentication-grpc` | `0.1.0` | `AuthenticationGRPC` for the bearer interceptors; `AuthenticationGRPCNIOTransport` for the certificate interceptor, only a package with an internal service |
| `swift-authentication-hummingbird` | `0.1.0` | `AuthenticationHummingbird`: `BearerAuthenticationMiddleware` for Hummingbird |
| `swift-authentication-vapor` | `0.1.0` | `AuthenticationVapor`: `BearerAuthenticationMiddleware` for Vapor 4 |
| `<project>-core` | first compatible tag | `<Project>Authentication`, `<Project>Persistence`, `<Project>Testing` |
| `<project>-protos` | first compatible tag | `<Module>Protos`, one product per module with a gRPC contract |
| `swift-container-plugin` | `1.3.0` | `build-container-image` command plugin |

Declare them at package level:

```swift
dependencies: [
    .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.8.2"),
    .package(url: "https://github.com/apple/swift-configuration.git", from: "1.2.0"),
    .package(url: "https://github.com/swift-server/swift-service-lifecycle.git", from: "2.11.0"),
    .package(url: "https://github.com/apple/swift-log.git", from: "1.15.0"),
    .package(url: "https://github.com/lovetodream/swift-log-loki.git", from: "2.0.0"),
    .package(url: "https://github.com/hummingbird-project/postgres-migrations.git", from: "1.2.0"),
    .package(url: "https://github.com/vapor/postgres-nio.git", from: "1.33.1"),
    .package(url: "https://github.com/grpc/grpc-swift-2.git", from: "2.4.0"),                 // with gRPC
    .package(url: "https://github.com/grpc/grpc-swift-nio-transport.git", from: "2.9.1"),     // with gRPC
    .package(url: "https://github.com/grpc/grpc-swift-extras.git", from: "2.2.0"),            // with gRPC
    .package(url: "https://github.com/grpc/grpc-swift-protobuf.git", from: "2.4.0"),          // with gRPC
    .package(url: "https://github.com/apple/swift-protobuf.git", from: "1.32.0"),             // with gRPC
    .package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "2.26.0"),  // with HTTP
    .package(url: "https://github.com/hummingbird-project/hummingbird-auth.git", from: "2.2.0"), // with HTTP, or a Bcrypt adapter
    .package(url: "https://github.com/apple/swift-openapi-generator.git", from: "1.13.0"),    // with HTTP
    .package(url: "https://github.com/apple/swift-openapi-runtime.git", from: "1.12.0"),      // with HTTP
    .package(url: "https://github.com/apple/swift-temporal-sdk.git", from: "1.0.0"),          // only with Temporal
    .package(url: "https://github.com/vapor/jwt-kit.git", "5.3.0"..<"5.7.0"),
    .package(url: "https://github.com/apple/swift-service-context.git", from: "1.3.0"),
    .package(url: "https://github.com/swift-microservices/swift-persistence.git", from: "0.1.0"),
    .package(url: "https://github.com/swift-microservices/swift-persistence-postgres.git", from: "0.1.0"),
    .package(url: "https://github.com/swift-microservices/swift-authentication.git", from: "0.1.0"),          // with HTTP
    .package(url: "https://github.com/swift-microservices/swift-authentication-jwt.git", from: "0.1.0"),
    .package(url: "https://github.com/swift-microservices/swift-authentication-grpc.git", from: "0.1.0"),     // with gRPC
    .package(url: "https://github.com/swift-microservices/swift-authentication-hummingbird.git", from: "0.1.0"), // with HTTP
    .package(url: "https://github.com/<organization>/<project>-core.git", from: "0.1.0"),
    .package(url: "https://github.com/<organization>/<project>-protos.git", from: "0.1.0"),   // with gRPC
    .package(url: "https://github.com/apple/swift-container-plugin.git", from: "1.3.0"),
]
```

Do not add every product to every target. Declare only the direct products imported by that target, and declare a package only when some target links one of its products; Xcode warns on a package no target uses. An HTTP-only package declares no grpc-swift, protobuf, or protos package; a gRPC-only package declares no Hummingbird or OpenAPI package. The container plugin is invoked from the package command line and is not attached to a source target.

Depend on organization packages by tagged URL, never by `.package(path:)`. A path dependency builds only where the sibling repository happens to be checked out, so CI and container builds fail on a package that resolves locally, and a package can silently build against uncommitted contract changes. Publish and tag first, then pin `from:` the release containing what the package imports. Contract additions are additive: tag them as a minor release so consumers on the same major range pick them up without a manifest edit. How to verify a cross-repository change before tagging is in [identity-and-access.md](identity-and-access.md) under *The packages*. A library package never commits `Package.resolved`; an executable package does, and re-resolves it when a dependency's tag moves.

After renaming a target, delete `.build` in that package and every consumer, or the stale `.swiftmodule` keeps the old module name and the compiler insists a module both exists and does not.

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
      <Entity>Client.swift                            # the narrow port, or the producer's XUseCaseProtocol re-declared
    <Feature>/Activities/                             # only with Temporal
      <Feature>ActivityService.swift
      <Feature>ActivityServiceProtocol.swift
  <Module>Postgres/
    Scopes/
      Postgres<Module>Scope.swift
      Postgres<Module>InternalScope.swift             # only a module with tenant tables
      Postgres<Module>WorkerScope.swift               # only with Temporal
    Migrations/
      <Module>Migrations.swift                        # the module's ordered list
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
    <Features>/
      <Entity>PublicService.swift
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
  <Module>Resend/
    Resend<Feature>EmailService.swift
Tests/
  <Module>CoreTests/
```

Use plural feature folders such as `Items`, then group repository and use-case artifacts within that feature. Do not create top-level `Entities`, `UseCases`, or `Repositories` buckets in Core. In Postgres, group by technical responsibility and then entity because those files implement infrastructure mechanics.

In GRPC, keep the generated-service conformances at the feature root, one file per proto service. Put every request/input and entity/message conversion in that feature's single `Protobuf/` directory, shared by the three. Do not split it further. In HTTP, keep one controller per resource and the conversions in `Schemas/`, matching the gateway's layout so a controller reads the same whether it calls a use case or a stub. The contents of the HTTP target are in [http.md](http.md).

There is no `Database/` in Core and no `Database/` in Postgres: the `Database` protocol comes from swift-persistence, `PostgresDatabase` and `PostgresScope` from swift-persistence-postgres, and the test double from `<Project>Testing`. There is no `Extensions/PostgresClient+withClient.swift` either; the driver ships it. The module writes scopes, statements, repositories, and migrations.

When Temporal is required, keep its SDK dependency and all macro-decorated Workflows and Activities in `<Module>Workflows`. Keep Core free of Temporal by defining the workflow-client and Activity-service protocols plus workflow state/result values there.

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
      TransportSecurity+ConfigReader.swift            # with gRPC
      LokiLogProcessorConfiguration+ConfigReader.swift
      EdDSA.PublicKey+ConfigReader.swift
      EdDSA.PrivateKey+ConfigReader.swift             # the monolith issues tokens, so it holds the private key
    Database/
      Migrations.swift                                # roles first, then every module's list in order
      Role/
        CreateServiceRole.swift
        CreateInternalRole.swift                      # only when any module has tenant tables
        CreateWorkerRole.swift                        # only with Temporal
    Serve/
      Serve.swift
    Worker/                                           # only with Temporal
      Worker.swift
      Run.swift
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
  CatalogCore/ CatalogPostgres/ CatalogHTTP/ CatalogGRPC/     # one module
  UsersCore/ UsersPostgres/ UsersHTTP/ UsersGRPC/ UsersBcrypt/ # another
Tests/
  CatalogCoreTests/
  UsersCoreTests/
```

The role migrations live at the executable because roles belong to the process and no module owns them. `<Project>HTTP` holds only what every `<Module>HTTP` shares; it never holds a controller.

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
      TransportSecurity+ConfigReader.swift
      LokiLogProcessorConfiguration+ConfigReader.swift
      EdDSA.PublicKey+ConfigReader.swift
      EdDSA.PrivateKey+ConfigReader.swift             # only the authenticating service
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
```

The service's `<Service>Postgres/Migrations/Role/` holds the role migrations, and `<Service>HTTP`, when it exists, holds its own `Contexts/` and `Middlewares/`.

## Source tree of a gateway

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

No `Database/`, no migrations, no `PostgresConfiguration`: a gateway owns no data.

## Manifest of a module's targets

The same block in every shape; the executable that links them differs.

```swift
.target(
    name: "<Module>Core",
    dependencies: [
        // The transaction boundary, the identities, and the swift-log facade. No driver, no
        // gRPC, no server framework: Core decides and never talks to a network.
        .product(name: "Persistence", package: "swift-persistence"),
        .product(name: "<Project>Authentication", package: "<project>-core"),
        .product(name: "Logging", package: "swift-log"),
    ]
),
.target(
    name: "<Module>Postgres",
    dependencies: [
        "<Module>Core",
        .product(name: "Logging", package: "swift-log"),
        .product(name: "PostgresMigrations", package: "postgres-migrations"),
        .product(name: "PostgresNIO", package: "postgres-nio"),
        .product(name: "PersistencePostgres", package: "swift-persistence-postgres"),
    ]
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
    plugins: [
        .plugin(name: "OpenAPIGenerator", package: "swift-openapi-generator")
    ]
),
.target(
    name: "<Module>GRPC",                                   // with gRPC
    dependencies: [
        "<Module>Core",
        .product(name: "GRPCCore", package: "grpc-swift-2"),
        .product(name: "GRPCProtobuf", package: "grpc-swift-protobuf"),
        .product(name: "SwiftProtobuf", package: "swift-protobuf"),
        .product(name: "ServiceContextModule", package: "swift-service-context"),
        .product(name: "<Project>Authentication", package: "<project>-core"),
        .product(name: "<Module>Protos", package: "<project>-protos"),
    ]
),
.target(
    name: "<Module>Workflows",                              // only with Temporal
    dependencies: [
        "<Module>Core",
        .product(name: "Temporal", package: "swift-temporal-sdk"),
    ]
),
.target(
    name: "<Module>Bcrypt",                                 // one adapter target per provider SDK
    dependencies: [
        "<Module>Core",
        .product(name: "HummingbirdBcrypt", package: "hummingbird-auth"),
    ]
),
.testTarget(
    name: "<Module>CoreTests",
    dependencies: [
        "<Module>Core",
        .product(name: "Logging", package: "swift-log"),
        .product(name: "<Project>Authentication", package: "<project>-core"),
        .product(name: "<Project>Testing", package: "<project>-core"),
    ]
),
```

A `<Module>GRPC` that consumes another service adds that service's `<Producer>Protos` product for its client adapter and nothing else; a `<Module>Core` never adds a protos product.

A gRPC monolith that keeps its contracts in the package (the default is `<project>-protos`; see *Canonical proto package* in [grpc-and-protos.md](grpc-and-protos.md)) drops the `<Module>Protos` product, puts the files under `Sources/<Module>GRPC/Protos/`, and generates in place:

```swift
.target(
    name: "CatalogGRPC",
    dependencies: [
        "CatalogCore",
        .product(name: "GRPCCore", package: "grpc-swift-2"),
        .product(name: "GRPCProtobuf", package: "grpc-swift-protobuf"),
        .product(name: "SwiftProtobuf", package: "swift-protobuf"),
        .product(name: "Logging", package: "swift-log"),
        .product(name: "ServiceContextModule", package: "swift-service-context"),
        .product(name: "<Project>Authentication", package: "<project>-core"),
    ],
    plugins: [.plugin(name: "GRPCProtobufGenerator", package: "grpc-swift-protobuf")]
),
```

The generated types stay `package`, and the day a second package needs the contract the `Protos/` folder moves into `<project>-protos` as that module's target and the plugin line goes with it.

## Manifest of a monolith

The module blocks above, once per module, plus the shared HTTP target and one executable:

```swift
.target(
    name: "<Project>HTTP",                                  // with HTTP
    dependencies: [
        .product(name: "Hummingbird", package: "hummingbird"),
        .product(name: "HummingbirdAuth", package: "hummingbird-auth"),
        .product(name: "<Project>Authentication", package: "<project>-core"),
    ]
),
.executableTarget(
    name: "<Project>",
    dependencies: [
        "CatalogCore", "CatalogPostgres", "CatalogHTTP", "CatalogGRPC",
        "UsersCore", "UsersPostgres", "UsersHTTP", "UsersGRPC", "UsersBcrypt",
        "<Project>HTTP",                                                             // with HTTP
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
        .product(name: "Configuration", package: "swift-configuration"),
        .product(name: "Hummingbird", package: "hummingbird"),                       // with HTTP
        .product(name: "HummingbirdAuth", package: "hummingbird-auth"),              // with HTTP
        .product(name: "AuthenticationHummingbird", package: "swift-authentication-hummingbird"), // with HTTP
        .product(name: "GRPCCore", package: "grpc-swift-2"),                         // with gRPC
        .product(name: "GRPCNIOTransportHTTP2", package: "grpc-swift-nio-transport"), // with gRPC
        .product(name: "GRPCServiceLifecycle", package: "grpc-swift-extras"),        // with gRPC
        .product(name: "AuthenticationGRPC", package: "swift-authentication-grpc"),  // with gRPC
        .product(name: "AuthenticationGRPCNIOTransport", package: "swift-authentication-grpc"), // only with an internal service
        .product(name: "AuthenticationJWT", package: "swift-authentication-jwt"),
        .product(name: "PersistencePostgres", package: "swift-persistence-postgres"),
        .product(name: "<Project>Authentication", package: "<project>-core"),
        .product(name: "<Project>Persistence", package: "<project>-core"),           // only when any module has tenant tables
        .product(name: "JWTKit", package: "jwt-kit"),
        .product(name: "ServiceContextModule", package: "swift-service-context"),
        .product(name: "Logging", package: "swift-log"),
        .product(name: "LoggingLoki", package: "swift-log-loki"),
        .product(name: "PostgresMigrations", package: "postgres-migrations"),
        .product(name: "PostgresNIO", package: "postgres-nio"),
        .product(name: "ServiceLifecycle", package: "swift-service-lifecycle"),
        .product(name: "Temporal", package: "swift-temporal-sdk"),                   // only with Temporal
    ]
),
```

The executable links every module's targets and is the only target that does. A module's targets never appear in another module's dependency list.

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
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
        .product(name: "Configuration", package: "swift-configuration"),
        .product(name: "GRPCCore", package: "grpc-swift-2"),                         // with gRPC
        .product(name: "GRPCNIOTransportHTTP2", package: "grpc-swift-nio-transport"), // with gRPC
        .product(name: "GRPCServiceLifecycle", package: "grpc-swift-extras"),        // with gRPC
        .product(name: "AuthenticationGRPC", package: "swift-authentication-grpc"),  // with gRPC
        .product(name: "AuthenticationGRPCNIOTransport", package: "swift-authentication-grpc"), // only with an internal service
        .product(name: "Hummingbird", package: "hummingbird"),                       // with HTTP
        .product(name: "HummingbirdAuth", package: "hummingbird-auth"),              // with HTTP
        .product(name: "AuthenticationHummingbird", package: "swift-authentication-hummingbird"), // with HTTP
        .product(name: "AuthenticationJWT", package: "swift-authentication-jwt"),
        .product(name: "PersistencePostgres", package: "swift-persistence-postgres"),
        .product(name: "<Project>Authentication", package: "<project>-core"),
        .product(name: "<Project>Persistence", package: "<project>-core"),           // only a module with tenant tables
        .product(name: "JWTKit", package: "jwt-kit"),
        .product(name: "ServiceContextModule", package: "swift-service-context"),
        .product(name: "Logging", package: "swift-log"),
        .product(name: "LoggingLoki", package: "swift-log-loki"),
        .product(name: "PostgresMigrations", package: "postgres-migrations"),
        .product(name: "PostgresNIO", package: "postgres-nio"),
        .product(name: "ServiceLifecycle", package: "swift-service-lifecycle"),
        .product(name: "Temporal", package: "swift-temporal-sdk"),                   // only with Temporal
    ]
),
```

Include a direct product dependency in every target that imports its module. The executable, not the feature target, needs `GRPCNIOTransportHTTP2` because it constructs the transport, and `AuthenticationHummingbird` because it builds the middleware. Remove any dependency a target does not import.

## Manifest of a gateway

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
        .product(name: "<Upstream>Protos", package: "<project>-protos"),             // one per upstream
        .product(name: "ServiceContextModule", package: "swift-service-context"),
        .product(name: "Logging", package: "swift-log"),
        .product(name: "LoggingLoki", package: "swift-log-loki"),
        .product(name: "NIOFoundationCompat", package: "swift-nio"),                 // swift-log-loki 2.0.0 omits it and nothing else here links it
        .product(name: "ServiceLifecycle", package: "swift-service-lifecycle"),
    ]
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
    ]
),
```

No `postgres-nio`, no `postgres-migrations`, no `swift-persistence`: a gateway declares no persistence package at all.

## Products

Do not expose internal library products by default. The executable is the package's one product:

```swift
products: [
    .executable(name: "<executable>", targets: ["<Project>"]),   // a monolith or a gateway
    .executable(name: "<service>", targets: ["<Service>"]),      // a service
]
```

Internal targets communicate through `package` declarations. The Temporal worker is a subcommand of this executable, not a second product: it links the same targets, and one image with two process types is simpler to build, publish and deploy than two images that must move together. What the worker must not do, open the server or read the verifying key, is a property of its command, not of the manifest. The worker once was a separate executable so the manifest could keep the database driver out of it; the worker owns its database now, so that edge enforces nothing.

Close every manifest with `swiftLanguageModes: [.v6]`.
