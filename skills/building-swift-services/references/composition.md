# Composition roots

## Contents

- [Command tree](#command-tree)
- [Environment configuration](#environment-configuration)
- [The serve composition root](#the-serve-composition-root)
- [A gRPC service with tenant tables](#a-grpc-service-with-tenant-tables)
- [A monolith serving HTTP and gRPC](monolith-composition.md#a-monolith-serving-http-and-grpc)
- [Two listeners: client-facing and internal](#two-listeners-client-facing-and-internal)
- [Lifecycle](#lifecycle)
- [The gateway composition root](#the-gateway-composition-root)
- [Transport security factories](transport-security.md#transport-security-factories)
- [Temporal worker composition root](#temporal-worker-composition-root)
- [Migrations at boot](#migrations-at-boot)
- [Operator commands](#operator-commands)

The composition root is the one place that knows the shape. It composes one module or many, registers the transport targets the shape serves, and satisfies every cross-module port with an adapter over a neighbor's use case or a gRPC client. Nothing below it knows which.

## Command tree

Name the executable target after the service or project; use a collision-safe name such as `AuthenticationServer` when a dependency already owns the default, and record it in `AGENTS.md`. The root command defaults to serving. Migrations run before the process serves: by default a `serve` flag applied in-process before the server binds; a platform that orders jobs runs them as a `migrate` subcommand one-shot instead; replicas that migrate at boot together serialize the apply with an advisory lock. The project records which (see [Migrations at boot](#migrations-at-boot)).

```text
backend                          # a monolith; a service reads `users`
backend serve
backend serve --migrate-database # apply pending migrations, then serve
backend worker run               # only with Temporal: the worker's composition root, same executable
backend migrate                  # the alternative: the same list as a one-shot before the rollout
```

```swift
import ArgumentParser

@main
struct Backend: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "backend",
        abstract: "The backend",
        subcommands: [
            Serve.self,
            Worker.self,   // only with Temporal
        ],
        defaultSubcommand: Serve.self
    )
}
```

Put commands in `<Project>/<Command>/` (or `<Service>/<Command>/`); the migration list lives at `<Project>/Database/Migrations.swift`.

## Environment configuration

Build `ConfigReader(providers: [EnvironmentVariablesProvider(), InMemoryProvider.applicationDefaults])` once, then scope by concern; [configuration.md](configuration.md) owns native readers, relative keys, application defaults, and validation. Swift Configuration turns camel-case scoped keys into variables:

```dotenv
POSTGRES_HOST=localhost
POSTGRES_PORT=5432
POSTGRES_USER=                       # the database's owner: migrations only
POSTGRES_PASSWORD=
POSTGRES_DB=<project>_users          # a service; a monolith's is <project>
POSTGRES_SERVICE_PASSWORD=           # <name>_service, the tenant-scoped role; the name defaults
POSTGRES_INTERNAL_PASSWORD=          # <name>_internal: only a package with tenant tables
HTTP_SERVER_HOST=0.0.0.0             # with HTTP
HTTP_SERVER_PORT=8080
GRPC_SERVER_HOST=0.0.0.0             # with gRPC
GRPC_SERVER_PORT=50051
GRPC_SERVER_MAX_CONNECTION_AGE_SECONDS=300
GRPC_INTERNAL_SERVER_PORT=50052      # only beside a client-facing listener: the internal mTLS one
GRPC_ACCOUNTS_HOST=accounts          # one scope per upstream service, required; a monolith has none
GRPC_ACCOUNTS_PORT=50051
TLS_CERTIFICATE_PATH=/run/tls/cert.pem       # every listener and client
TLS_PRIVATE_KEY_PATH=/run/tls/key.pem
TLS_TRUST_ROOTS_PATH=/run/tls/ca.pem
TLS_REFRESH_INTERVAL_SECONDS=60
JWT_PUBLIC_KEY_PATH=/run/secrets/jwt-public
JWT_PRIVATE_KEY_PATH=/run/secrets/jwt-private  # only the process that issues tokens
LOKI_URL=http://loki:3100
LOG_LEVEL=info
```

`<name>` is the service name in a service and the project name in a monolith: `users_service` and `backend_service`. Roles belong to the process, so a monolith's ten modules share one set. Temporal's keys, the worker role's password, and the worker's own scope are in the orchestrating-temporal-workflows skill's [worker.md](../../orchestrating-temporal-workflows/references/worker.md).

The composition root reads the `postgres` scope itself, in Infrastructure: the host, port, and database, each role's name and password, and one `PostgresClient.Configuration` per role it connects as. A command reads only the credentials of the roles it connects as or creates: `serve` the service and internal roles, the owner pair (`user` and `password`, the instance's own variables) only under `--migrate-database`, a worker only its own role. A missing secret fails at startup, naming the key, because every command builds its clients before its `ServiceGroup` runs. No type wraps these values; each command reads what it uses.

A package with no tenant tables drops the internal role; with Temporal, `serve` reads `workerUser` and `workerPassword` only to migrate. Require topology and secrets where no appropriate default exists; put mount paths, database and role names, listener bindings, and URLs in the application defaults provider. Key material is configured as a path and opened by the cryptographic library, so it fails at startup naming the path ([identity-and-access.md](identity-and-access.md#key-material-in-configuration)). Where the values come from in a running environment is the delivering-swift-services skill's subject.

## The serve composition root

`Serve.run()` has these `// MARK:` sections in this order, keeping only the transport sections the shape serves: Configuration, Logging, Infrastructure, Composition, Router and Hummingbird (with HTTP), gRPC (with gRPC), Lifecycle. A process serving both transports has one root, one set of use cases, and one `ServiceGroup` holding the application and the server; never two roots for two transports. The two files below are complete; copy the one that matches the shape and delete what the package does not have.

- **Logging** is bootstrapped inline, never behind a shared helper: a `MultiplexLogHandler` of `StreamLogHandler.standardOutput` and one in-process shipper, the process name as the service label, and `<Project>Authentication`'s `.user` metadata provider, so every line inside a request carries `user_id`. The default shipper is `swift-log-loki`; the alternative is any `LogHandler` the deployment prefers (stdout alone where the platform collects it, or OTLP), and substituting one changes only this block.
- **Infrastructure** builds one `PostgresClient` per role the process connects as, the token verifier from the mounted public key, the certificate reloader, one `GRPCClient` per upstream service, and, with Temporal, one `TemporalClient`.
- **Composition** builds one `PostgresDatabase` per module per role over the shared clients, then policies, use cases (each over the database its scope admits, passing `logger`), the cross-module adapters, and one transport implementation per contract. Say in a comment which database each use case runs on and why: that sentence is the authorization design.

## A gRPC service with tenant tables

A users service: a person reads their own profile under the tenant policy; administrators read anyone on `UserService`; the authentication process resolves users on `UserInternalService`. Only the gateway and other processes dial a microservice, so its one listener is internal and requires mTLS for both descriptors.

```swift
// Sources/Users/Serve/Serve.swift
import ArgumentParser
import AuthenticationGRPC
import AuthenticationJWT
import Configuration
import GRPCCore
import GRPCNIOTransportHTTP2
import GRPCServiceLifecycle
import JWTKit
import Logging
import LoggingLoki
import NIOCertificateReloading
import PersistencePostgres
import PostgresNIO
import ServiceLifecycle
import UnixSignals
import UsersCore
import UsersGRPC
import UsersPostgres
import UsersProtos
import <Project>Authentication
import <Project>Persistence

struct Serve: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "serve",
        abstract: "Start the gRPC server"
    )

    @Flag(help: "Apply pending database migrations before serving")
    var migrateDatabase = false

    func run() async throws {
        // MARK: - Configuration
        let config = ConfigReader(providers: [EnvironmentVariablesProvider(), InMemoryProvider.applicationDefaults])
        let postgresConfig = config.scoped(to: "postgres")
        let tlsConfig = config.scoped(to: "tls")
        let serverConfig = config.scoped(to: "grpc.server")

        // MARK: - Logging
        let lokiProcessor = LokiLogProcessor(
            configuration: try LokiLogProcessorConfiguration(config: config.scoped(to: "loki"))
        )
        let logLevel = config.string(forKey: "logLevel", default: Logger.Level.info)
        LoggingSystem.bootstrap(
            { label, metadataProvider in
                var handler = MultiplexLogHandler([
                    StreamLogHandler.standardOutput(label: label, metadataProvider: metadataProvider),
                    LokiLogHandler(label: label, service: "users", processor: lokiProcessor),
                ])
                handler.logLevel = logLevel
                handler.metadataProvider = metadataProvider
                return handler
            },
            metadataProvider: .user
        )
        let logger = Logger(label: "users")

        // MARK: - Infrastructure
        // One database, a role per purpose. The owner pair is read only to migrate; nothing that
        // serves connects with it.
        let postgresHost = try postgresConfig.requiredString(forKey: "host")
        let postgresPort = postgresConfig.int(forKey: "port", default: 5432)
        let databaseName = try postgresConfig.requiredString(forKey: "db")
        let serviceUser = try postgresConfig.requiredString(forKey: "serviceUser")
        let servicePassword = try postgresConfig.requiredString(forKey: "servicePassword", isSecret: true)
        let internalUser = try postgresConfig.requiredString(forKey: "internalUser")
        let internalPassword = try postgresConfig.requiredString(forKey: "internalPassword", isSecret: true)

        if migrateDatabase {
            let owner = try PostgresClient.Configuration(
                host: postgresHost,
                port: postgresPort,
                username: postgresConfig.requiredString(forKey: "user"),
                password: postgresConfig.requiredString(forKey: "password", isSecret: true),
                database: databaseName,
                tls: .prefer(.clientDefault)   // `.require` where the database is reached over a network the deployment does not control
            )
            try await PostgresClient.withClient(configuration: owner, logger: logger) { client in
                try await Migrations(
                    client: client,
                    database: databaseName,
                    serviceUser: serviceUser,
                    servicePassword: servicePassword,
                    internalUser: internalUser,
                    internalPassword: internalPassword,
                    logger: logger
                ).run()
            }
        }

        let serviceClient = PostgresClient(
            configuration: PostgresClient.Configuration(
                host: postgresHost,
                port: postgresPort,
                username: serviceUser,
                password: servicePassword,
                database: databaseName,
                tls: .prefer(.clientDefault)
            ),
            backgroundLogger: logger
        )
        let internalClient = PostgresClient(
            configuration: PostgresClient.Configuration(
                host: postgresHost,
                port: postgresPort,
                username: internalUser,
                password: internalPassword,
                database: databaseName,
                tls: .prefer(.clientDefault)
            ),
            backgroundLogger: logger
        )
        let userAuthenticator = await JWTAuthenticator<UserIdentity>(
            publicKey: try EdDSA.PublicKey(config: config.scoped(to: "jwt"))
        )
        var reloaderConfig = try TimedCertificateReloader.Configuration(config: tlsConfig)
        reloaderConfig.logger = logger
        reloaderConfig.onCertificateLoadFailed = { failure in
            logger.warning("TLS certificate reload failed", metadata: ["error": "\(failure.error)"])
        }
        let certificateReloader = try TimedCertificateReloader.makeReloaderValidatingSources(
            configuration: reloaderConfig
        )

        // MARK: - Composition
        // Who may call an RPC decides its database. The caller's own profile runs on `database`, as
        // users_service, where the tenant policy confines the transaction to the caller's row. The
        // administrators' reads (each use case refusing anyone else) and the internal service's
        // resolve need every row, so they run on `internalDatabase`, as users_internal.
        let database = PostgresDatabase<PostgresUsersScope>(client: serviceClient, logger: logger)
        let internalDatabase = PostgresDatabase<PostgresUsersInternalScope>(client: internalClient, logger: logger)

        let userService = UserService(
            getProfileUseCase: GetProfileUseCase(database: database, logger: logger),
            getUserByIdUseCase: GetUserByIDUseCase(database: internalDatabase, logger: logger),
            listUsersUseCase: ListUsersUseCase(database: internalDatabase, logger: logger)
        )
        let userInternalService = UserInternalService(
            resolveUserUseCase: ResolveUserUseCase(database: internalDatabase, logger: logger)
        )

        // MARK: - gRPC
        let host = try serverConfig.requiredString(forKey: "host")
        let port = try serverConfig.requiredInt(forKey: "port")
        let server = GRPCServer(
            transport: .http2NIOPosix(
                address: .ipv4(host: host, port: port),
                transportSecurity: try .mTLS(config: tlsConfig, certificateReloader: certificateReloader),
                config: HTTP2ServerTransport.Posix.Config(config: serverConfig)
            ),
            services: [userService, userInternalService],
            // UserService identifies the caller and binds the tenant setting; each handler requires
            // what its RPC needs. UserInternalService carries no application interceptor: the
            // listener's mTLS admits the peer.
            interceptorPipeline: [
                .apply(
                    BearerAuthenticationInterceptor(authenticator: userAuthenticator),
                    to: .services([<Organization>_Users_V1_UserService.descriptor])
                ),
                .apply(
                    UserSettingsInterceptor(),
                    to: .services([<Organization>_Users_V1_UserService.descriptor])
                ),
            ]
        )

        // MARK: - Lifecycle
        let serviceGroup = ServiceGroup(
            services: [lokiProcessor, serviceClient, internalClient, certificateReloader, server],
            gracefulShutdownSignals: [.sigint, .sigterm],
            logger: logger
        )

        logger.info("Starting on \(host):\(port)")
        try await serviceGroup.run()
    }
}
```

A service with no tenant tables has one client, one database over `Postgres<Service>Scope`, and no `UserSettingsInterceptor`. A service that calls another adds, under Infrastructure, one `GRPCClient` per upstream with `.mTLS(config:certificateReloader:)`, `ServiceConfig.defaults`, and `BearerPropagationInterceptor<UserIdentity>()` on the upstream's `<Entity>Service` descriptors alone, wraps it in the consumer adapter under Composition, and adds the client to the `ServiceGroup` ([grpc-and-protos.md](grpc-and-protos.md#consumer-adapter)).

## Two listeners: client-facing and internal

A process that apps or partners call directly and that another process also calls runs two `GRPCServer`s in one `ServiceGroup`, over the same use cases and reloader: the client-facing one carries every `<Entity>Service` behind the bearer and settings interceptors on server TLS; the internal one, on its own port, carries every `<Entity>InternalService` on mTLS with no application interceptor. Never register an internal descriptor on the client-facing listener.

```swift
// MARK: - gRPC
let internalServerConfig = config.scoped(to: "grpc.internalServer")
let server = GRPCServer(
    transport: .http2NIOPosix(
        address: .ipv4(host: try serverConfig.requiredString(forKey: "host"), port: try serverConfig.requiredInt(forKey: "port")),
        transportSecurity: try .serverTLS(certificateReloader: certificateReloader),          // the edge proxy dials it
        config: HTTP2ServerTransport.Posix.Config(config: serverConfig)
    ),
    services: [userService],
    interceptorPipeline: [
        .apply(BearerAuthenticationInterceptor(authenticator: userAuthenticator), to: .services([<Organization>_Users_V1_UserService.descriptor])),
        .apply(UserSettingsInterceptor(), to: .services([<Organization>_Users_V1_UserService.descriptor])),
    ]
)
let internalServer = GRPCServer(
    transport: .http2NIOPosix(
        address: .ipv4(host: try internalServerConfig.requiredString(forKey: "host"), port: try internalServerConfig.requiredInt(forKey: "port")),
        transportSecurity: try .mTLS(config: tlsConfig, certificateReloader: certificateReloader),  // processes only
        config: HTTP2ServerTransport.Posix.Config(config: internalServerConfig)
    ),
    services: [userInternalService]
)
// Lifecycle: [lokiProcessor, serviceClient, internalClient, certificateReloader, server, internalServer]
```

The internal port is reachable only on the private network and never routed by the edge proxy. A microservice behind a gateway does not split: only processes dial it, so its one listener is internal.

## Lifecycle

One `ServiceGroup` owns every long-lived runnable dependency with graceful shutdown on `.sigint` and `.sigterm` (from `UnixSignals`): the log processor, every `PostgresClient`, every certificate reloader, every `GRPCClient`, the application with HTTP, the server with gRPC, both when both. With Temporal, `serve` also builds one long-lived `TemporalClient`, injects `<Feature>WorkflowClient` adapters into Core use cases, and adds the client to the group; it never runs workflow definitions or Activities ([worker.md](../../orchestrating-temporal-workflows/references/worker.md)).

A project may record borrowed SDK-managed HTTP singletons such as `HTTPClient.shared` as a lifecycle exception in `AGENTS.md`. The application does not own or shut down that singleton; an explicitly constructed HTTP client remains the application's shutdown responsibility.

## The gateway composition root

A gateway's root — the authenticator, one mTLS `GRPCClient` per upstream with bearer propagation on `<Entity>Service` descriptors, the router, and no database — is the building-swift-http-surfaces skill's, in its [gateway reference](../../building-swift-http-surfaces/references/gateway.md#composition-root). It uses the transport security factories below.

## Temporal worker composition root

The worker is `worker run` on the same executable, in `<Project>/Worker/` or `<Service>/Worker/`: its own composition root with a Worker section in place of the transport sections, the worker role and scope, no server, and no verifying key. Its command group, root, configuration readers, and TLS are the orchestrating-temporal-workflows skill's [worker.md](../../orchestrating-temporal-workflows/references/worker.md).

## Migrations at boot

`serve --migrate-database` applies migrations after the logging bootstrap and before any long-lived client exists, over an owner client that lives exactly as long as the apply: `PostgresClient.withClient` from `PersistencePostgres` starts it in a task group and cancels it when the operation returns or throws (both roots above). The long-lived clients connect as the service and internal roles and never hold owner credentials. The owner pair does sit in the serving container's environment, which is the accepted price of migrating in-process: the *process* that serves never connects with it.

`Migrations` is a small struct in `Database/Migrations.swift`. What goes in the list, and in what order, is [migrations-and-rls.md](migrations-and-rls.md#the-migration-list)'s:

```swift
// Sources/Backend/Database/Migrations.swift
import CatalogPostgres
import Logging
import PostgresMigrations
import PostgresNIO
import UsersPostgres

/// Every migration, in the order databases apply them, over a short-lived owner connection. Only append.
struct Migrations {
    let client: PostgresClient
    let database: String
    let serviceUser: String
    let servicePassword: String
    let internalUser: String
    let internalPassword: String
    let logger: Logger

    func run() async throws {
        let migrations = DatabaseMigrations()
        await migrations.add(CreateServiceRole(role: serviceUser, password: servicePassword, database: database))
        await migrations.add(CreateInternalRole(role: internalUser, password: internalPassword, database: database))
        await migrations.add(CreateUsersTable())
        await migrations.add(CreateUsersRLSPolicy(internalRole: internalUser))
        await migrations.add(CreateItemsTable())   // items are not tenant rows: no policy

        try await migrations.apply(client: client, logger: logger, dryRun: false)
        logger.info("Migrations applied")
    }
}
```

In a monolith the role migrations are the executable's own (`Database/Role/`); in a service they come from `<Service>Postgres`, which the file imports.

The flag is the default because it needs no platform support: one container, one command, and the schema is current before the port opens. The alternative is a `migrate` subcommand running the same `Migrations.run()` and exiting, deployed as a one-shot job before the rollout, for a platform that orders jobs or starts several replicas at once; replicas that migrate at boot instead serialize the apply with a Postgres advisory lock around the list. Either way nothing serves an unmigrated schema, and only the migration client connects as the owner.

## Operator commands

An operation that must never be reachable over the network, a data repair, a one-off export, is a subcommand, run by an operator against the package's own database. It follows the boot-migration shape: short-lived, stdout logging, a scoped client around the work. Print exactly the value the operator needs on standard output and nothing else there, so a redirect captures it.
