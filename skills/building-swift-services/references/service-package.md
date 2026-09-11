# Service SwiftPM package

## Contents

- Package initialization
- Dependency baseline
- Exact source tree
- Manifest shape

## Package initialization

Initialize the directory first:

```bash
swift package init --type executable
```

Then reshape the generated package. Keep the Swift tools version, Swift language mode 6, the platform floor, and dependency versions aligned across the organization's repositories unless the user asks to upgrade.

## Dependency baseline

These are the packages the architecture is built on. The versions are a floor from when this skill was last revised, not an instruction to downgrade a repository that already uses compatible newer releases; align with the organization's other services first, then with the newest compatible release.

| Package | Baseline | Products/purpose |
| --- | --- | --- |
| `swift-argument-parser` | `1.8.2` | `ArgumentParser` for the command tree |
| `swift-configuration` | `1.2.0` | `Configuration` and `EnvironmentVariablesProvider` |
| `swift-service-lifecycle` | `2.11.0` | `ServiceLifecycle` and `ServiceGroup` |
| `swift-log` | `1.15.0` | `Logging` facade (also linked by `<Service>Core` so use cases log domain events) |
| `swift-log-loki` | `2.0.0` | `LoggingLoki` — in-process log shipping to the aggregator |
| `swift-nio` | `2.65.0` | `NIOFoundationCompat` — declared on an executable that links `LoggingLoki` but not PostgresNIO (the gateway); swift-log-loki 2.0.0 omits it |
| `postgres-migrations` | `1.2.0` | `PostgresMigrations` |
| `postgres-nio` | `1.33.1` | `PostgresNIO`, `PostgresClient`, prepared statements, transactions |
| `grpc-swift-2` | `2.4.0` | `GRPCCore`, `GRPCClient`, `GRPCServer` |
| `grpc-swift-nio-transport` | `2.9.1` | `GRPCNIOTransportHTTP2` |
| `grpc-swift-extras` | `2.2.0` | `GRPCServiceLifecycle` adapters |
| `grpc-swift-protobuf` | `2.4.0` | `GRPCProtobuf` and `GRPCProtobufGenerator` |
| `swift-protobuf` | `1.32.0` | `SwiftProtobuf` messages and well-known types |
| `swift-temporal-sdk` | `1.0.0` | `Temporal` — only with durable orchestration |
| `hummingbird-auth` | current | `HummingbirdBcrypt` — only in a `<Service>Bcrypt` adapter target |
| `jwt-kit` | `"5.3.0"..<"5.7.0"` | `JWTKit` — the executable, for the EdDSA key types; the pin's reason is in identity-and-access.md |
| `swift-service-context` | `1.3.0` | `ServiceContextModule` — wherever `ServiceContext.current` is read: the GRPC target and the executable |
| `swift-persistence` | `0.1.0` | `Persistence` — `Database<Scope>`, linked by Core |
| `swift-persistence-postgres` | `0.1.0` | `PersistencePostgres` — `PostgresDatabase`, `PostgresScope`, `PostgresSettings`, `PostgresClient.withClient` |
| `swift-authentication-jwt` | `0.1.0` | `AuthenticationJWT` — `JWTAuthenticator<UserIdentity>` in the executable, `JWTIssuer<UserIdentity>` in the authenticating service |
| `swift-authentication-grpc` | `0.1.0` | `AuthenticationGRPC` for the bearer interceptors; `AuthenticationGRPCNIOTransport` for the certificate interceptor, only a service with an internal service |
| `<project>-core` | first compatible tag | `<Project>Authentication`, `<Project>Persistence`, `<Project>Testing` |
| `<project>-protos` | first compatible tag | `<Service>Protos` |
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
    .package(url: "https://github.com/grpc/grpc-swift-2.git", from: "2.4.0"),
    .package(url: "https://github.com/grpc/grpc-swift-nio-transport.git", from: "2.9.1"),
    .package(url: "https://github.com/grpc/grpc-swift-extras.git", from: "2.2.0"),
    .package(url: "https://github.com/grpc/grpc-swift-protobuf.git", from: "2.4.0"),
    .package(url: "https://github.com/apple/swift-protobuf.git", from: "1.32.0"),
    .package(url: "https://github.com/apple/swift-temporal-sdk.git", from: "1.0.0"), // only with Temporal
    .package(url: "https://github.com/vapor/jwt-kit.git", "5.3.0"..<"5.7.0"),
    .package(url: "https://github.com/apple/swift-service-context.git", from: "1.3.0"),
    .package(url: "https://github.com/swift-microservices/swift-persistence.git", from: "0.1.0"),
    .package(url: "https://github.com/swift-microservices/swift-persistence-postgres.git", from: "0.1.0"),
    .package(url: "https://github.com/swift-microservices/swift-authentication-jwt.git", from: "0.1.0"),
    .package(url: "https://github.com/swift-microservices/swift-authentication-grpc.git", from: "0.1.0"),
    .package(url: "https://github.com/<organization>/<project>-core.git", from: "0.1.0"),
    .package(url: "https://github.com/<organization>/<project>-protos.git", from: "0.1.0"),
    .package(url: "https://github.com/apple/swift-container-plugin.git", from: "1.3.0"),
]
```

Do not add every product to every target. Declare only the direct products imported by that target, and declare a package only when some target links one of its products — Xcode warns on a package no target uses. The container plugin is invoked from the package command line and is not attached to a source target.

Depend on organization packages by tagged URL, never by `.package(path:)`. A path dependency builds only where the sibling repository happens to be checked out, so CI and container builds fail on a package that resolves locally — and a service can silently build against uncommitted contract changes. Publish and tag first, then pin `from:` the release containing what the service imports. Contract additions are additive: tag them as a minor release so consumers on the same major range pick them up without a manifest edit. How to verify a cross-repository change before tagging is in [identity-and-access.md](identity-and-access.md) under *The packages*. A library package never commits `Package.resolved`; a service executable does, and re-resolves it when a dependency's tag moves.

After renaming a target, delete `.build` in that package and every consumer, or the stale `.swiftmodule` keeps the old module name and the compiler insists a module both exists and does not.

## Exact source tree

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
      Run.swift                                       # `worker run` — the worker's composition root
  <Service>Core/
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
    <Feature>/Activities/          # only with Temporal
      <Feature>ActivityService.swift
      <Feature>ActivityServiceProtocol.swift
  <Service>Postgres/
    Scopes/
      Postgres<Service>Scope.swift
      Postgres<Service>InternalScope.swift            # only a tenant service
      Postgres<Service>WorkerScope.swift              # only with Temporal
    Migrations/
      Role/
        CreateServiceRole.swift
        CreateInternalRole.swift                      # only a tenant service
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
  <Service>GRPC/
    <Features>/
      <Entity>PublicService.swift
      <Entity>Service.swift
      <Entity>InternalService.swift                   # one conformance per proto service the contract has
      Protobuf/
        <Entity>+Protobuf.swift
        Create<Entity>UseCaseInput+Protobuf.swift
  <Service>Workflows/              # only with Temporal
    <Feature>/
      <Feature>Workflow.swift
      <Feature>Activities.swift
      Temporal<Feature>WorkflowClient.swift
  <Service>Bcrypt/                 # one target per provider SDK
    BcryptPasswordHasher.swift
  <Service>Resend/
    Resend<Feature>EmailService.swift
```

Use plural feature folders such as `Items`, then group repository and use-case artifacts within that feature. Do not create top-level `Entities`, `UseCases`, or `Repositories` buckets in Core. In Postgres, group by technical responsibility and then entity because those files implement infrastructure mechanics.

In GRPC, keep the generated-service conformances at the feature root, one file per proto service. Put every request/input and entity/message conversion in that feature's single `Protobuf/` directory, shared by the three. Do not split it further.

There is no `Database/` in Core and no `Database/` in Postgres: the `Database` protocol comes from swift-persistence, `PostgresDatabase` and `PostgresScope` from swift-persistence-postgres, and the test double from `<Project>Testing`. There is no `Extensions/PostgresClient+withClient.swift` either; the driver ships it. The service writes scopes, statements, repositories, and migrations.

When Temporal is required, keep its SDK dependency and all macro-decorated Workflows and Activities in `<Service>Workflows`. Keep Core free of Temporal by defining the workflow-client and Activity-service protocols plus workflow state/result values there.

## Manifest shape

```swift
targets: [
    .target(
        name: "<Service>Core",
        dependencies: [
            // The transaction boundary, the identities, and the swift-log facade. No driver, no
            // gRPC, no server framework: Core decides and never talks to a network.
            .product(name: "Persistence", package: "swift-persistence"),
            .product(name: "<Project>Authentication", package: "<project>-core"),
            .product(name: "Logging", package: "swift-log"),
        ]
    ),
    .target(
        name: "<Service>Postgres",
        dependencies: [
            "<Service>Core",
            .product(name: "Logging", package: "swift-log"),
            .product(name: "PostgresMigrations", package: "postgres-migrations"),
            .product(name: "PostgresNIO", package: "postgres-nio"),
            .product(name: "PersistencePostgres", package: "swift-persistence-postgres"),
        ]
    ),
    .target(
        name: "<Service>GRPC",
        dependencies: [
            "<Service>Core",
            .product(name: "GRPCCore", package: "grpc-swift-2"),
            .product(name: "GRPCProtobuf", package: "grpc-swift-protobuf"),
            .product(name: "SwiftProtobuf", package: "swift-protobuf"),
            .product(name: "ServiceContextModule", package: "swift-service-context"),
            .product(name: "<Project>Authentication", package: "<project>-core"),
            .product(name: "<Service>Protos", package: "<project>-protos"),
        ]
    ),
    .target(
        name: "<Service>Workflows",
        dependencies: [
            "<Service>Core",
            .product(name: "Temporal", package: "swift-temporal-sdk"),
        ]
    ), // only with Temporal
    .target(
        name: "<Service>Bcrypt",
        dependencies: [
            "<Service>Core",
            .product(name: "HummingbirdBcrypt", package: "hummingbird-auth"),
        ]
    ), // one adapter target per provider SDK
    .executableTarget(
        name: "<Service>",
        dependencies: [
            "<Service>Core",
            "<Service>GRPC",
            "<Service>Postgres",
            "<Service>Workflows", // only with Temporal — serve starts workflows, worker runs them
            .product(name: "ArgumentParser", package: "swift-argument-parser"),
            .product(name: "Configuration", package: "swift-configuration"),
            .product(name: "GRPCCore", package: "grpc-swift-2"),
            .product(name: "GRPCNIOTransportHTTP2", package: "grpc-swift-nio-transport"),
            .product(name: "GRPCServiceLifecycle", package: "grpc-swift-extras"),
            .product(name: "AuthenticationGRPC", package: "swift-authentication-grpc"),
            .product(name: "AuthenticationGRPCNIOTransport", package: "swift-authentication-grpc"), // only with an internal service
            .product(name: "AuthenticationJWT", package: "swift-authentication-jwt"),
            .product(name: "PersistencePostgres", package: "swift-persistence-postgres"),
            .product(name: "<Project>Authentication", package: "<project>-core"),
            .product(name: "<Project>Persistence", package: "<project>-core"), // only a tenant service
            .product(name: "JWTKit", package: "jwt-kit"),
            .product(name: "ServiceContextModule", package: "swift-service-context"),
            .product(name: "Logging", package: "swift-log"),
            .product(name: "LoggingLoki", package: "swift-log-loki"),
            .product(name: "PostgresMigrations", package: "postgres-migrations"),
            .product(name: "PostgresNIO", package: "postgres-nio"),
            .product(name: "ServiceLifecycle", package: "swift-service-lifecycle"),
            .product(name: "Temporal", package: "swift-temporal-sdk"), // only with Temporal
        ]
    ),
],
swiftLanguageModes: [.v6]
```

Include a direct product dependency in every target that imports its module. The executable — not the feature target — needs `GRPCNIOTransportHTTP2` because it constructs the transport. Remove any dependency a target does not import.

Do not expose internal library products by default. The executable is the package's one product:

```swift
products: [
    .executable(name: "<service>", targets: ["<Service>"]),
]
```

Internal targets communicate through `package` declarations. The Temporal worker is a subcommand of this executable, not a second product: it links the same targets, and one image with two process types is simpler to build, publish and deploy than two images that must move together. What the worker must not do — open the server, read the verifying key — is a property of its command, not of the manifest. The worker once was a separate executable so the manifest could keep the database driver out of it; the worker owns its service's database now, so that edge enforces nothing.
