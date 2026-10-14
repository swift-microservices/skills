# Composition roots

## Contents

- [Command tree](#command-tree)
- [Environment configuration](#environment-configuration)
- [The serve composition root](#the-serve-composition-root)
- [A gRPC service with tenant tables](#a-grpc-service-with-tenant-tables)
- [A monolith serving HTTP and gRPC](#a-monolith-serving-http-and-grpc)
- [Two listeners: client-facing and internal](#two-listeners-client-facing-and-internal)
- [Lifecycle](#lifecycle)
- [The gateway composition root](#the-gateway-composition-root)
- [Transport security factories](#transport-security-factories)
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

`PostgresConfiguration` owns every connection the process makes. Each connection reads its password when it is asked for rather than in `init`, so one type serves every command: `serve` reads the service and internal roles, `serve --migrate-database` (or `migrate`) the owner too, and a missing secret still fails at startup, naming the key, because every command builds its clients before its `ServiceGroup` runs. The password properties are exposed for the role migrations.

```swift
// Sources/Users/Configuration/PostgresConfiguration.swift
import Configuration
import PostgresNIO

struct PostgresConfiguration: Sendable {
    let host: String
    let port: Int
    let database: String
    let serviceUser: String
    let internalUser: String                                   // only with tenant tables
    private let config: ConfigReader

    init(config: ConfigReader) throws {
        self.host = try config.requiredString(forKey: "host")
        self.port = config.int(forKey: "port", default: 5432)
        self.database = try config.requiredString(forKey: "db")
        self.serviceUser = try config.requiredString(forKey: "serviceUser")
        self.internalUser = try config.requiredString(forKey: "internalUser")
        self.config = config
    }

    /// The owner: migrations only. Nothing that serves connects with it.
    var owner: PostgresClient.Configuration {
        get throws {
            try connection(
                user: config.requiredString(forKey: "user"),
                password: config.requiredString(forKey: "password", isSecret: true)
            )
        }
    }

    /// The tenant-scoped role, for the public and the caller's own operations.
    var service: PostgresClient.Configuration {
        get throws { try connection(user: serviceUser, password: servicePassword) }
    }

    var servicePassword: String {
        get throws { try config.requiredString(forKey: "servicePassword", isSecret: true) }
    }

    /// The role that sees every row, for administrators and other processes.
    var internalService: PostgresClient.Configuration {
        get throws { try connection(user: internalUser, password: internalPassword) }
    }

    var internalPassword: String {
        get throws { try config.requiredString(forKey: "internalPassword", isSecret: true) }
    }

    private func connection(user: String, password: String) -> PostgresClient.Configuration {
        PostgresClient.Configuration(
            host: host,
            port: port,
            username: user,
            password: password,
            database: database,
            tls: .prefer(.clientDefault)   // `.require` where the database is reached over a network the deployment does not control
        )
    }
}
```

A package with no tenant tables drops `internalUser` and its two properties; with Temporal, `workerUser`, `worker`, and `workerPassword` follow the same shape. Require topology and secrets where no appropriate default exists; put mount paths, database and role names, listener bindings, and URLs in the application defaults provider. Key material is configured as a path and opened by the cryptographic library, so it fails at startup naming the path ([identity-and-access.md](identity-and-access.md#key-material-in-configuration)). Where the values come from in a running environment is the delivering-swift-services skill's subject.

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
        let postgres = try PostgresConfiguration(config: config.scoped(to: "postgres"))
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
        if migrateDatabase {
            try await PostgresClient.withClient(configuration: postgres.owner, logger: logger) { client in
                try await Migrations(client: client, configuration: postgres, logger: logger).run()
            }
        }

        let serviceClient = try PostgresClient(configuration: postgres.service, backgroundLogger: logger)
        let internalClient = try PostgresClient(configuration: postgres.internalService, backgroundLogger: logger)
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

## A monolith serving HTTP and gRPC

Apps call this monolith directly, so both its listeners are client-facing: server TLS with the stack's leaf, verified by the edge proxy, and no client certificate ([identity-and-access.md](identity-and-access.md#validation-at-every-process-boundary)). Two modules: Users has tenant rows (profiles), so it has a database per role; catalogue items are not tenant rows, so Catalog has one scope over the service role. Catalog's Core declares an `AccountClient` port, and the root satisfies it with `UsersAccountClient`, the executable-local adapter in `Sources/Backend/Ports/` shown in [core.md](core.md#ports-to-other-modules). The monolith issues tokens, so it reads the private key and verifies with its public half.

```swift
// Sources/Backend/Serve/Serve.swift
import ArgumentParser
import AuthenticationGRPC
import AuthenticationHummingbird
import AuthenticationJWT
import BackendAuthentication
import BackendHTTP
import BackendPersistence
import CatalogCore
import CatalogGRPC
import CatalogHTTP
import CatalogPostgres
import Configuration
import GRPCCore
import GRPCNIOTransportHTTP2
import GRPCServiceLifecycle
import Hummingbird
import HummingbirdAuth
import HummingbirdTLS
import JWTKit
import Logging
import LoggingLoki
import NIOCertificateReloading
import PersistencePostgres
import PostgresNIO
import ServiceLifecycle
import UnixSignals
import UsersBcrypt
import UsersCore
import UsersGRPC
import UsersHTTP
import UsersPostgres

struct Serve: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "serve",
        abstract: "Serve HTTP and gRPC"
    )

    @Flag(help: "Apply pending database migrations before serving")
    var migrateDatabase = false

    func run() async throws {
        // MARK: - Configuration
        let config = ConfigReader(providers: [EnvironmentVariablesProvider(), InMemoryProvider.applicationDefaults])
        let postgres = try PostgresConfiguration(config: config.scoped(to: "postgres"))
        let tlsConfig = config.scoped(to: "tls")
        let grpcServerConfig = config.scoped(to: "grpc.server")

        // MARK: - Logging
        let lokiProcessor = LokiLogProcessor(
            configuration: try LokiLogProcessorConfiguration(config: config.scoped(to: "loki"))
        )
        let logLevel = config.string(forKey: "logLevel", default: Logger.Level.info)
        LoggingSystem.bootstrap(
            { label, metadataProvider in
                var handler = MultiplexLogHandler([
                    StreamLogHandler.standardOutput(label: label, metadataProvider: metadataProvider),
                    LokiLogHandler(label: label, service: "backend", processor: lokiProcessor),
                ])
                handler.logLevel = logLevel
                handler.metadataProvider = metadataProvider
                return handler
            },
            metadataProvider: .user
        )
        let logger = Logger(label: "backend")

        // MARK: - Infrastructure
        if migrateDatabase {
            try await PostgresClient.withClient(configuration: postgres.owner, logger: logger) { client in
                try await Migrations(client: client, configuration: postgres, logger: logger).run()
            }
        }

        let serviceClient = try PostgresClient(configuration: postgres.service, backgroundLogger: logger)
        let internalClient = try PostgresClient(configuration: postgres.internalService, backgroundLogger: logger)
        let signingKey = try EdDSA.PrivateKey(config: config.scoped(to: "jwt"))
        let userIssuer = await JWTIssuer<UserIdentity>(privateKey: signingKey)
        let userAuthenticator = await JWTAuthenticator<UserIdentity>(publicKey: signingKey.publicKey)
        var reloaderConfig = try TimedCertificateReloader.Configuration(config: tlsConfig)
        reloaderConfig.logger = logger
        reloaderConfig.onCertificateLoadFailed = { failure in
            logger.warning("TLS certificate reload failed", metadata: ["error": "\(failure.error)"])
        }
        let certificateReloader = try TimedCertificateReloader.makeReloaderValidatingSources(
            configuration: reloaderConfig
        )

        // MARK: - Composition
        // Two clients, one per role; one database per module per role it uses.
        let usersDatabase = PostgresDatabase<PostgresUsersScope>(client: serviceClient, logger: logger)
        let usersInternalDatabase = PostgresDatabase<PostgresUsersInternalScope>(client: internalClient, logger: logger)
        let catalogDatabase = PostgresDatabase<PostgresCatalogScope>(client: serviceClient, logger: logger)

        // Users, the producer, first. Sign-in finds an account by email before any caller is bound,
        // so it runs on the internal role; a person's own profile runs under the tenant policy; an
        // administrator's read of any user, and the resolve Catalog calls, run on the internal role.
        let signInUseCase = SignInUseCase(
            database: usersInternalDatabase,
            passwordHasher: BcryptPasswordHasher(),
            issuer: userIssuer,
            logger: logger
        )
        let getProfileUseCase = GetProfileUseCase(database: usersDatabase, logger: logger)
        let getUserByIdUseCase = GetUserByIDUseCase(database: usersInternalDatabase, logger: logger)
        let resolveUserUseCase = ResolveUserUseCase(database: usersInternalDatabase, logger: logger)

        // Catalog, the consumer. Its AccountClient port is Users' resolve behind the adapter. Were
        // Users its own service, this one argument would be GRPCAccountClient over a GRPCClient,
        // and nothing in CatalogCore would change.
        let accounts = UsersAccountClient(resolveUserUseCase: resolveUserUseCase)
        let createItemUseCase = CreateItemUseCase(database: catalogDatabase, accounts: accounts, logger: logger)
        let listItemsUseCase = ListItemsUseCase(database: catalogDatabase, logger: logger)

        // One transport implementation per contract and transport, over the same use cases.
        let userController = UserController(
            signInUseCase: signInUseCase,
            getProfileUseCase: getProfileUseCase,
            getUserByIdUseCase: getUserByIdUseCase
        )
        let itemController = ItemController(createItemUseCase: createItemUseCase, listItemsUseCase: listItemsUseCase)
        let userService = UserService(
            signInUseCase: signInUseCase,
            getProfileUseCase: getProfileUseCase,
            getUserByIdUseCase: getUserByIdUseCase
        )
        let itemService = ItemService(createItemUseCase: createItemUseCase, listItemsUseCase: listItemsUseCase)

        // MARK: - Router
        let router = Router(context: BasicRequestContext.self)
        router.add(middleware: ErrorMiddleware())
        router.add(middleware: LogRequestsMiddleware(.info))
        let v1 = router.group("v1")

        // Tier 1: no caller. Session-issuing routes and the health route.
        userController.addPublicRoutes(to: v1.group("auth"))
        v1.get("health") { _, _ in HTTPResponse.Status.ok }

        // Tier 2: a caller if there is one; the bound user becomes the tenant setting.
        let identified = v1.group(context: IdentityRequestContext.self)
            .add(middleware: BearerAuthenticationMiddleware<IdentityRequestContext>(authenticator: userAuthenticator))
            .add(middleware: UserSettingsMiddleware())

        // Tier 3: a caller is required.
        let authenticated = identified.group().add(middleware: IsAuthenticatedMiddleware())
        userController.addAuthenticatedRoutes(to: authenticated.group("users"))
        itemController.addAuthenticatedRoutes(to: authenticated.group("items"))

        // MARK: - Hummingbird
        // Client-facing: TLS to the edge proxy, no client certificate; the bearer middleware identifies.
        let application = Application(
            router: router,
            server: try .tls(.http1(), tlsConfiguration: .makeServerConfiguration(certificateReloader: certificateReloader)),
            configuration: ApplicationConfiguration(reader: config.scoped(to: "http.server")),
            logger: logger
        )

        // MARK: - gRPC
        // Client-facing too: only <Entity>Service descriptors, each behind the bearer interceptor.
        let server = GRPCServer(
            transport: .http2NIOPosix(
                address: .ipv4(
                    host: try grpcServerConfig.requiredString(forKey: "host"),
                    port: try grpcServerConfig.requiredInt(forKey: "port")
                ),
                transportSecurity: try .serverTLS(certificateReloader: certificateReloader),
                config: HTTP2ServerTransport.Posix.Config(config: grpcServerConfig)
            ),
            services: [userService, itemService],
            interceptorPipeline: [
                .apply(
                    BearerAuthenticationInterceptor(authenticator: userAuthenticator),
                    to: .services([
                        <Organization>_Users_V1_UserService.descriptor,
                        <Organization>_Catalog_V1_ItemService.descriptor,
                    ])
                ),
                .apply(
                    UserSettingsInterceptor(),
                    to: .services([<Organization>_Users_V1_UserService.descriptor])   // items are not tenant rows
                ),
            ]
        )

        // MARK: - Lifecycle
        let serviceGroup = ServiceGroup(
            services: [lokiProcessor, serviceClient, internalClient, certificateReloader, application, server],
            gracefulShutdownSignals: [.sigint, .sigterm],
            logger: logger
        )
        try await serviceGroup.run()
    }
}
```

- The root, and only the root, imports every module. Compose producers before consumers, so a port is satisfied by a value that already exists; a cycle between two modules' ports is a design fault, resolved by reconsidering ownership, never by a lazy reference. Keep the port call outside the consumer's `withTransaction` ([core.md](core.md#database-boundary)).
- An HTTP-only monolith drops the gRPC section and the gRPC transport-security files and keeps the reloader, because its listener serves TLS too; a gRPC-only one drops Router and Hummingbird. When another process calls in — a worker or a service on an internal descriptor — the monolith adds the internal listener below. The Router and Hummingbird sections are the building-swift-http-surfaces skill's ([surface.md](../../building-swift-http-surfaces/references/surface.md#composition)).
- The descriptors come from each `<Module>GRPC`, where the in-package contracts are generated. A monolith dials nothing over gRPC unless it consumes a service outside itself, and its modules never call each other over the network.
- A symmetric key, where the project records one, replaces the two key lines with an `HMACKey` read by `HMACKey+ConfigReader.swift` and added to one `JWTKeyCollection` both the issuer and the authenticator take ([identity-and-access.md](identity-and-access.md#one-issuer-asymmetric-keys)).

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

## Transport security factories

Configure service connections with the `tls` reader; each scope has its own certificate/key pair and trust bundle from application defaults, and adapters accept a reader, not a directory or default-path argument ([configuration.md](configuration.md)). Declare `NIOCertificateReloading` from swift-nio-extras and `GRPCServiceLifecycle` from grpc-swift-extras directly in the executable. Prime one `TimedCertificateReloader` per credential pair before constructing any transport, as both roots above do; `makeReloaderValidatingSources` loads and validates the initial pair without starting the reload loop. Own the reloader exactly once in the same `ServiceGroup` as the transports, and share it across clients and the listener only when the pair supports both purposes.

```swift
// Sources/<Service>/Configuration/HTTP2ClientTransport.Posix.TransportSecurity+ConfigReader.swift
import Configuration
import GRPCNIOTransportHTTP2
import NIOCertificateReloading

extension HTTP2ClientTransport.Posix.TransportSecurity {
    static func mTLS(config: ConfigReader, certificateReloader: any CertificateReloader) throws -> Self {
        let trustRootsPath = try config.requiredString(forKey: "trustRootsPath")
        return try .mTLS(certificateReloader: certificateReloader) {
            $0.trustRoots = .certificates([.file(path: trustRootsPath, format: .pem)])
            $0.serverCertificateVerification = .fullVerification
        }
    }
}
```

```swift
// Sources/<Service>/Configuration/HTTP2ServerTransport.Posix.TransportSecurity+ConfigReader.swift
import Configuration
import GRPCNIOTransportHTTP2
import NIOCertificateReloading

extension HTTP2ServerTransport.Posix.TransportSecurity {
    static func mTLS(config: ConfigReader, certificateReloader: any CertificateReloader) throws -> Self {
        let trustRootsPath = try config.requiredString(forKey: "trustRootsPath")
        return try .mTLS(certificateReloader: certificateReloader) {
            $0.trustRoots = .certificates([.file(path: trustRootsPath, format: .pem)])
            $0.clientCertificateVerification = .noHostnameVerification
        }
    }
}
```

Server-side `.noHostnameVerification` still requires and verifies a client certificate against explicit trust; clients retain full chain and hostname verification. That is every internal listener.

A client-facing listener — apps or partners behind the edge proxy — presents the same leaf and requires no client certificate; the bearer interceptor identifies its callers. Add it to the same file:

```swift
extension HTTP2ServerTransport.Posix.TransportSecurity {
    /// Client-facing: server-side TLS the edge proxy verifies; callers are identified by bearer JWT.
    static func serverTLS(certificateReloader: any CertificateReloader) throws -> Self {
        try .tls(certificateReloader: certificateReloader) {
            $0.clientCertificateVerification = .doNotVerify
        }
    }
}
```

An HTTP listener gets the same with HummingbirdTLS: `server: try .tls(.http1(), tlsConfiguration: .makeServerConfiguration(certificateReloader: certificateReloader))`. The leaf's DNS SANs include the name the proxy dials. No listener has a plaintext mode.

Server connection settings, including keepalive, come from the `grpc.server` reader:

```swift
// Sources/<Service>/Configuration/HTTP2ServerTransport.Posix.Config+ConfigReader.swift
import Configuration
import GRPCNIOTransportHTTP2

extension HTTP2ServerTransport.Posix.Config {
    init(config: ConfigReader) {
        let maxConnectionAge = config.int(forKey: "maxConnectionAgeSeconds", as: Duration.self, default: .seconds(300))
        let connectionGraceTime = config.int(forKey: "connectionGraceTimeSeconds", as: Duration.self, default: .seconds(30))
        self = .defaults {
            $0.connection.maxAge = maxConnectionAge
            $0.connection.maxGraceTime = connectionGraceTime
            // Accept idle client pings through the service load balancer.
            $0.connection.keepalive.clientBehavior = .init(minPingIntervalWithoutCalls: .seconds(60), allowWithoutCalls: true)
        }
    }
}
```

Choose the connection age below the certificate's renewal budget so connections re-handshake onto renewed leaves. The reloader changes the leaf pair used on new handshakes; it does not issue certificates, refresh a trust bundle, or re-authenticate existing connections, and a failed update keeps the last usable pair. Issuance, renewal, expiry monitoring, and CA rotation are the delivery skill's ([environment reference](../../delivering-swift-services/references/environment.md#transport-security-the-certificate-volume)).

**Every client waits for the connection, bounded by a deadline.** A call made while its channel is not ready fails fast by default, which a caller hits after an idle period, a peer restart, or a rolling deploy. Set *wait-for-ready* once, client-wide, through the empty-service global `MethodConfig` bucket, with a `timeout` so a down upstream still fails:

```swift
extension ServiceConfig {
    static let defaults = ServiceConfig(
        methodConfig: [
            MethodConfig(
                names: [MethodConfig.Name(service: "")],  // "": every method of every service
                waitForReady: true,
                timeout: .seconds(15)
            )
        ]
    )
}
```

Pass it as `serviceConfig:` to every client's `.http2NIOPosix`, beside the mTLS factory. A call's `CallOptions` fill only fields the call sets, so `ServiceConfig` is the base default and `CallOptions` the per-RPC override. `GRPCServer` takes no service config.

Temporal always has its own credential scope, `temporal.tls`, and its own primed reloader; see [worker.md](../../orchestrating-temporal-workflows/references/worker.md).

## Temporal worker composition root

The worker is `worker run` on the same executable, in `<Project>/Worker/` or `<Service>/Worker/`: its own composition root with a Worker section in place of the transport sections, the worker role and scope, no server, and no verifying key. Its command group, root, configuration readers, and TLS are the orchestrating-temporal-workflows skill's [worker.md](../../orchestrating-temporal-workflows/references/worker.md).

## Migrations at boot

`serve --migrate-database` applies migrations after the logging bootstrap and before any long-lived client exists, over an owner client that lives exactly as long as the apply: `PostgresClient.withClient` from `PersistencePostgres` starts it in a task group and cancels it when the operation returns or throws (both roots above). The long-lived clients are built from `postgres.service` and `postgres.internalService` and never hold owner credentials. The owner pair does sit in the serving container's environment, which is the accepted price of migrating in-process: the *process* that serves never connects with it.

`Migrations` is a small struct in `Database/Migrations.swift`. What goes in the list, and in what order, is [persistence.md](persistence.md#the-migration-list)'s:

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
    let configuration: PostgresConfiguration
    let logger: Logger

    func run() async throws {
        let migrations = DatabaseMigrations()
        try await migrations.add(
            CreateServiceRole(role: configuration.serviceUser, password: configuration.servicePassword, database: configuration.database)
        )
        try await migrations.add(
            CreateInternalRole(role: configuration.internalUser, password: configuration.internalPassword, database: configuration.database)
        )
        await migrations.add(CreateUsersTable())
        await migrations.add(CreateUsersRLSPolicy(internalRole: configuration.internalUser))
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
