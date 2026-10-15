# The monolith package

A modular monolith's source tree and manifest. Package initialization, the dependency baseline, a module's targets, and products are in [service-package.md](service-package.md).

## Contents

- [Source tree of a monolith](#source-tree-of-a-monolith)
- [Manifest of a monolith](#manifest-of-a-monolith)

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
  UsersGRPCTests/                                     # with gRPC: handler tests and one loopback suite per module that serves RPCs
  CatalogWorkflowsTests/                              # only with Temporal, per module with workflows
```

The role migrations live at the executable because roles belong to the process and no module owns them. `<Project>HTTP` holds only what every `<Module>HTTP` shares; it never holds a controller. `Ports/` holds only adapters that convert one module's use case into another module's port ([core.md](core.md#ports-to-other-modules)).

`<Project>Authentication`, `<Project>Persistence`, and `<Project>Testing` are what `<project>-core` would hold, as in-package targets with `package` access; their contents are the building-swift-server-libraries skill's [organization-layer.md](../../building-swift-server-libraries/references/organization-layer.md). The day a second package needs them, they move to a tagged `<project>-core` unchanged except for `public` access, the same rule as in-package protos, and the manifest swaps each target name for the product.

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
