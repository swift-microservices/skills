# The monolith composition root

The complete root of a modular monolith that serves HTTP and gRPC from one executable. The command tree, environment configuration, the service root, lifecycle, and migrations at boot are in [composition.md](composition.md); the transport security factories are in [transport-security.md](transport-security.md).

## Contents

- [A monolith serving HTTP and gRPC](#a-monolith-serving-http-and-grpc): the complete `Serve.swift`, section by section


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
