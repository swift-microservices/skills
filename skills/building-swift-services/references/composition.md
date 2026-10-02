# Composition roots

## Contents

- Command tree
- Environment configuration
- The serve composition root
- Composing a monolith
- The HTTP sections
- The gRPC section
- Lifecycle
- The gateway composition root
- Transport security factories
- Temporal worker composition root
- Migrations at boot
- Operator commands

The composition root is the one place that knows the shape. It composes one module or many, registers the transport targets the shape serves, and satisfies every cross-module port with a neighbor's use case or a gRPC client. Nothing below it knows which.

## Command tree

Name the executable target after the service or the project, not `<Service>Server`. The root command defaults to serving. Migrations run before the process serves; by default they are a `serve` flag applied in-process before the server binds, and a platform that orders jobs or starts several replicas at once runs them as a `migrate` subcommand one-shot instead (see *Migrations at boot* below).

```text
backend                          # a monolith; a service reads `catalog`
backend serve
backend serve --migrate-database # apply pending migrations, then serve
backend worker run               # only with Temporal: the worker's composition root, same executable
backend migrate                  # the alternative: the same list as a one-shot before the rollout
```

```swift
@main
struct Backend: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "backend",
        abstract: "Acme Backend",
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

Build `ConfigReader(providers: [EnvironmentVariablesProvider(), InMemoryProvider.applicationDefaults])` once, then scope by concern. See [configuration.md](configuration.md) for native library readers, relative keys, application defaults, and validation boundaries. Swift Configuration transforms camel-case scoped keys into variables:

```dotenv
POSTGRES_HOST=localhost
POSTGRES_PORT=5432
POSTGRES_USER=…                      # the instance's owner, verbatim: migrations only
POSTGRES_PASSWORD=…
POSTGRES_DB=<project>_catalog        # a service; a monolith's is <project>
POSTGRES_SERVICE_PASSWORD=…          # <name>_service, the tenant-scoped role; the name defaults
POSTGRES_INTERNAL_PASSWORD=…         # <name>_internal: only a package with tenant tables
POSTGRES_WORKER_PASSWORD=…           # <name>_worker: only the worker's environment
HTTP_SERVER_HOST=0.0.0.0             # with HTTP
HTTP_SERVER_PORT=8080
GRPC_SERVER_HOST=0.0.0.0             # with gRPC
GRPC_SERVER_PORT=50051
GRPC_ACCOUNTS_HOST=accounts          # one scope per upstream service, required; a monolith has none
GRPC_ACCOUNTS_PORT=50051
TLS_CERTIFICATE_PATH=/run/tls/cert.pem       # with gRPC
TLS_PRIVATE_KEY_PATH=/run/tls/key.pem
TLS_TRUST_ROOTS_PATH=/run/tls/ca.pem
TLS_REFRESH_INTERVAL_SECONDS=60
TEMPORAL_TLS_CERTIFICATE_PATH=/run/temporal-tls/cert.pem
TEMPORAL_TLS_PRIVATE_KEY_PATH=/run/temporal-tls/key.pem
TEMPORAL_TLS_TRUST_ROOTS_PATH=/run/temporal-tls/ca.pem
TEMPORAL_TLS_REFRESH_INTERVAL_SECONDS=60
JWT_PUBLIC_KEY_PATH=/run/secrets/jwt-public
JWT_PRIVATE_KEY_PATH=/run/secrets/jwt-private  # only the process that issues tokens
TEMPORAL_HOST=temporal
TEMPORAL_PORT=7233
TEMPORAL_CLIENT_NAMESPACE=production                      # serve: the SDK's own client keys
TEMPORAL_CLIENT_INSTRUMENTATION_SERVERHOSTNAME=temporal
TEMPORAL_WORKER_NAMESPACE=production                      # worker: the SDK's own worker keys
TEMPORAL_WORKER_TASKQUEUE=catalog
TEMPORAL_WORKER_BUILDID=production
TEMPORAL_WORKER_CLIENT_IDENTITY=catalog-worker
TEMPORAL_WORKER_CLIENT_INSTRUMENTATION_SERVERHOSTNAME=temporal
TEMPORAL_WORKER_HEARTBEATINTERVALMS=60000                 # worker liveness; the SDK default disables
LOKI_URL=http://loki:3100
LOG_LEVEL=info
```

`<name>` is the service name in a service and the project name in a monolith: `catalog_service` and `backend_service`. Roles belong to the process, so a monolith's ten modules share one set.

Prefer native library readers. For types without one, add a focused `Type+ConfigReader.swift` in the executable. Read relative keys and delegate to the existing initializer; keep deployment defaults in the application provider. Do not pass extra default or directory arguments.

```swift
struct PostgresConfiguration: Sendable {
    let host: String; let port: Int; let database: String
    let serviceUser: String                                   // the tenant-scoped role
    let internalUser: String                                  // only with tenant tables
    let workerUser: String                                    // only with Temporal
    private let config: ConfigReader

    init(config: ConfigReader) throws {
        self.host = try config.requiredString(forKey: "host")
        self.port = config.int(forKey: "port", default: 5432)
        self.database = config.string(forKey: "db", default: "<project>_<service>")
        self.serviceUser = config.string(forKey: "serviceUser", default: "<name>_service")
        self.internalUser = config.string(forKey: "internalUser", default: "<name>_internal")
        self.workerUser = config.string(forKey: "workerUser", default: "<name>_worker")
        self.config = config
    }

    /// The owner: migrations only. Read when asked for, so a command that never migrates never needs it.
    var owner: PostgresClient.Configuration {
        get throws { try connection(user: config.requiredString(forKey: "user"), password: config.requiredString(forKey: "password", isSecret: true)) }
    }
    var service: PostgresClient.Configuration { get throws { try connection(user: serviceUser, password: servicePassword) } }
    var servicePassword: String { get throws { try config.requiredString(forKey: "servicePassword", isSecret: true) } }
    // internalService / internalPassword and worker / workerPassword, the same shape
}
```

Each connection reads its password when it is asked for rather than in `init`. That is what lets one type serve every command: `serve` reads the service and internal roles, `serve --migrate-database` the owner too, and `worker run` the worker role alone, so the worker's environment carries neither the owner pair nor the serving roles' secrets, and a missing secret still fails at startup, naming the key, because every command builds its clients before its `ServiceGroup` runs. The password properties are exposed so the role migrations can read them.

Require topology and secrets where no appropriate default exists. Put application mount paths, database/role names, and task queues in the application defaults provider; library tuning defaults belong to their readers. A local application-specific wrapper such as `PostgresConfiguration` can own its process defaults. Use the pinned library’s documented required keys and native scoping.

Key material, signing keys and certificates, is configured as a path and file loading is delegated to the configured cryptographic library. A path is the form NIOSSL and grpc-swift already take credentials in, it keeps a private key out of the environment, and it fails at startup naming the path. The rationale is in [identity-and-access.md](identity-and-access.md), *Key material in configuration*.

Where the values come from in a running environment is the delivering-swift-services skill's subject.

## The serve composition root

Use these section comments in this order, keeping only the transport sections the shape serves:

```swift
func run() async throws {
    // MARK: - Configuration
    // MARK: - Logging
    // MARK: - Infrastructure
    // MARK: - Composition
    // MARK: - Router          // with HTTP
    // MARK: - Hummingbird     // with HTTP
    // MARK: - gRPC            // with gRPC
    // MARK: - Lifecycle
}
```

A process serving both transports has one root, one set of use cases, and one `ServiceGroup` holding both the application and the server. Do not write two roots for two transports.

**Logging.** Bootstrap the logging system inline, never behind a shared helper or module. Build one in-process log shipper, then `LoggingSystem.bootstrap` a `MultiplexLogHandler` of `StreamLogHandler.standardOutput` and the shipper's handler, so every line reaches both the container's stdout and the aggregator. Pass the process name as the handler's service label, and `<Project>Authentication`'s metadata providers as the bootstrap's, so every log line inside a request carries the bound caller, `user_id`, with no handler naming them. The rule is the shape: structured logs, one aggregator, the label and the providers on every line. The default shipper is `swift-log-loki` to Grafana Loki; the alternative is any `LogHandler` the deployment prefers — `StreamLogHandler` alone where the platform collects stdout, or an OTLP handler — and substituting one changes only this block.

```swift
// MARK: - Logging
let lokiProcessor = LokiLogProcessor(
    configuration: LokiLogProcessorConfiguration(config: config.scoped(to: "loki"))
)
let logLevel = config.string(forKey: "logLevel", default: Logger.Level.info)
LoggingSystem.bootstrap(
    { label, metadataProvider in
        var handler = MultiplexLogHandler([
            StreamLogHandler.standardOutput(label: label, metadataProvider: metadataProvider),
            LokiLogHandler(label: label, service: "catalog", processor: lokiProcessor),
        ])
        handler.logLevel = logLevel
        handler.metadataProvider = metadataProvider
        return handler
    },
    metadataProvider: .user
)
let logger = Logger(label: "catalog")
```

**Infrastructure.** Construct one `PostgresClient` per role the process connects as, the service role and, wherever tenant tables exist, the internal role; the token verifier from the mounted public key; one `GRPCClient` per upstream service; and, with Temporal, one `TemporalClient`. Scope the transport-security reader once:

```swift
let tlsConfig = config.scoped(to: "tls")
let serviceClient = PostgresClient(configuration: postgres.service, backgroundLogger: logger)
let internalClient = PostgresClient(configuration: postgres.internalService, backgroundLogger: logger)
let userAuthenticator = await JWTAuthenticator<UserIdentity>(publicKey: try EdDSA.PublicKey(config: config.scoped(to: "jwt")))
```

A monolith has no upstream service and dials nothing over gRPC unless it consumes a service outside itself; every `GRPCClient` in a microservice is one upstream, one connection, with the factory and service config in *Transport security factories*.

**Composition.** Construct one `PostgresDatabase` per module per role over the shared clients, `PostgresDatabase<Postgres<Module>Scope>(client:logger:)` over the service client and `PostgresDatabase<Postgres<Module>InternalScope>(client:logger:)` over the internal one, then policies, use cases (each over the database its scope admits, passing `logger`), workflow-client adapters, and one transport implementation per contract: a gRPC service per proto service, a controller per resource. Say in a comment which database each use case runs on and why, because that sentence is the authorization design.

## Composing a monolith

The root of a monolith does what a service's root does, once per module, and one thing more: it satisfies each module's cross-module ports with another module's use case.

```swift
// MARK: - Composition
// Two clients, one per role; one database per module per role. Every tenant-scoped database
// reads the same caller setting, bound once at the transport.
let catalogDatabase = PostgresDatabase<PostgresCatalogScope>(client: serviceClient, logger: logger)
let catalogInternalDatabase = PostgresDatabase<PostgresCatalogInternalScope>(client: internalClient, logger: logger)
let usersDatabase = PostgresDatabase<PostgresUsersScope>(client: serviceClient, logger: logger)
let usersInternalDatabase = PostgresDatabase<PostgresUsersInternalScope>(client: internalClient, logger: logger)

// Users: the module every other module asks about accounts.
let getAccountUseCase = GetAccountUseCase(database: usersInternalDatabase, logger: logger)
let usersController = UserController(getAccount: getAccountUseCase, /* … */)

// Catalog: its AccountClient port is Users' use case, called locally. Were Users its own service,
// this one line would inject GRPCAccountClient over a GRPCClient instead, and nothing in
// CatalogCore would change.
let createItemUseCase = CreateItemUseCase(database: catalogDatabase, accounts: getAccountUseCase, logger: logger)
let itemController = ItemController(createItem: createItemUseCase, /* … */)
let itemService = ItemService(createItem: createItemUseCase, /* … */)          // with gRPC
```

Compose modules in dependency order, producers before consumers, so a port is satisfied by a value that already exists. A cycle between two modules' ports is a design fault; resolve it by reconsidering ownership, never by a lazy reference. A transaction never spans the local call, exactly as it never spans a remote one: the consumer's use case calls the port before or after its own `withTransaction`, not inside it.

The root, and only the root, imports every module. A module that imports another compiles today and cannot be moved tomorrow.

## The HTTP sections

Under **Router**, build one router on `BasicRequestContext` and register every module's controllers in the three tiers of [http.md](http.md). The tiers are the same for a module and for a gateway; what differs is that a module's tier 2 carries `UserSettingsMiddleware` after the bearer middleware wherever tenant tables exist, so the caller the middleware bound becomes the setting the policies read:

```swift
// MARK: - Router
let router = Router(context: BasicRequestContext.self)
router.add(middleware: ErrorMiddleware())
router.add(middleware: LogRequestsMiddleware(.info))

let v1 = router.group("v1")

// Tier 1: no caller. Session-issuing routes and the health route.
usersController.addPublicRoutes(to: v1.group("auth"))
v1.get("health") { _, _ in HTTPResponse.Status.ok }

// Tier 2: a caller if there is one. The settings middleware turns a bound user into the tenant setting.
let identified = v1.group(context: IdentityRequestContext.self)
    .add(middleware: BearerAuthenticationMiddleware<IdentityRequestContext>(authenticator: userAuthenticator))
    .add(middleware: UserSettingsMiddleware())
itemController.addIdentifiedRoutes(to: identified.group("items"))

// Tier 3: a caller is required.
let authenticated = identified.add(middleware: IsAuthenticatedMiddleware())
itemController.addAuthenticatedRoutes(to: authenticated.group("items"))
usersController.addAuthenticatedRoutes(to: authenticated.group("profile"))
```

`BearerAuthenticationMiddleware` comes from `AuthenticationHummingbird` and takes any `Authenticator<String, UserIdentity>`; `UserSettingsMiddleware` comes from `<Project>Persistence`, beside `UserSettingsInterceptor`, and reads what the bearer middleware bound, so it follows it and never precedes it. Keep the path prefix here and the routes in the controllers, so one file shows the whole surface and each controller stays movable. A monolith with a dozen modules has a dozen `add…Routes` lines per tier and nothing else.

Under **Hummingbird**, build the application from the router and the listener read by `ApplicationConfiguration(reader:)` scoped to `http.server`:

```swift
// MARK: - Hummingbird
let application = Application(
    router: router,
    configuration: ApplicationConfiguration(reader: config.scoped(to: "http.server")),
    logger: logger
)
```

The application publishes no host port of its own; the address comes from the ingress that proxies to it (the delivering-swift-services skill). On Vapor 4 the same sections build a `Vapor.Application`, register the tiers as route groups, and run under `ServiceContext.withValue(req.serviceContext)` where a route calls out, as [http.md](http.md) describes.

## The gRPC section

Construct one server with every proto service the process serves, every module's in a monolith, and apply each interceptor to the service whose audience it identifies:

```swift
// MARK: - gRPC
let serverConfig = config.scoped(to: "grpc.server")
let server = GRPCServer(
    transport: .http2NIOPosix(
        address: .ipv4(
            host: serverConfig.string(forKey: "host", default: "0.0.0.0"),
            port: serverConfig.int(forKey: "port", default: 50051)
        ),
        transportSecurity: try .mTLS(config: tlsConfig, certificateReloader: certificateReloader)
    ),
    services: [itemPublicService, itemService, itemInternalService, userPublicService, userService],
    interceptorPipeline: [
        .apply(
            BearerAuthenticationInterceptor(authenticator: userAuthenticator),
            to: .services([
                <Organization>_Catalog_V1_ItemService.descriptor,
                <Organization>_Users_V1_UserService.descriptor,
            ])
        ),
        .apply(
            UserSettingsInterceptor(),   // only where tenant tables exist: the bound user becomes the tenant setting
            to: .services([
                <Organization>_Catalog_V1_ItemService.descriptor,
                <Organization>_Users_V1_UserService.descriptor,
            ])
        ),
    ]
)
```

Public and internal descriptors have no application authentication interceptor. `BearerAuthenticationInterceptor` binds users only on user descriptors; `UserSettingsInterceptor` follows it for tenant operations. The backend listener still requires mTLS for every descriptor. Keep internal operations private and outside gateway routes. A monolith uses local calls between its modules rather than internal network hops.

## Lifecycle

Own every long-lived thing with ServiceLifecycle:

```swift
// MARK: - Lifecycle
let serviceGroup = ServiceGroup(
    services: [lokiProcessor, certificateReloader, serviceClient, internalClient, accountsClient, application, server],
    gracefulShutdownSignals: [.sigint, .sigterm],
    logger: logger
)
try await serviceGroup.run()
```

Include the application with HTTP, the server with gRPC, both when both. When the package uses Temporal, construct one long-lived `TemporalClient` in `serve`, inject a `<Feature>WorkflowClient` adapter into Core use cases, and include the client in `ServiceGroup`. Do not run workflow definitions or Activity implementations in the serving process.

## The gateway composition root

A gateway is the HTTP transport of a system whose modules are services; its root follows the section order above with Router and Hummingbird and no gRPC section, and its Infrastructure holds no database. Under Infrastructure, build the authenticator, `JWTAuthenticator<UserIdentity>` over the public key by path through the EdDSA initializer `<Project>Authentication` adds, exactly as [identity-and-access.md](identity-and-access.md) describes, and one `GRPCClient` per upstream, each with a required host and port and the stack's mTLS client factory. Every upstream is one connection and two audiences, so the caller's token is resent only on the proto service that takes one, through one interceptor applied per descriptor:

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
        .apply(propagation, to: .services([<Organization>_Users_V1_UserService.descriptor]))
    ]
)
```

Under Composition, wrap each client in one generated stub per proto service, `UserPublicService.Client(wrapping:)` and `UserService.Client(wrapping:)` over the same `GRPCClient`, and hand the pair to the controller. The public stub is dialled with nothing, which is what the session-issuing RPCs expect: they run before any caller exists, so there is no token to forward. The gateway exposes only intended public and user operations; its mTLS credential must not be treated as permission to publish internal routes.

Under Router, the same three tiers as a module's, without `UserSettingsMiddleware`: a gateway has no database for the setting to reach, and the tenant is bound again, from the forwarded token, inside the service that owns the rows. Under Hummingbird, `ApplicationConfiguration(reader:)` scoped to `http.server`. Under Lifecycle, the application and every client in one `ServiceGroup`:

```swift
let serviceGroup = ServiceGroup(
    services: [lokiProcessor, certificateReloader, authenticationClient, usersClient, application],
    gracefulShutdownSignals: [.sigint, .sigterm],
    logger: logger
)
```

The gateway publishes no host port and needs no migration job; give it a health route in tier 1 so the platform can probe it without a token. Its tests are in [testing.md](testing.md).

## Transport security factories

Configure service connections with the `tls` reader and Temporal with `temporal.tls`. Each scope has its own certificate/key pair and trust bundle from application defaults. Use the configuration pattern in [configuration.md](configuration.md); adapters accept a reader, not a directory or default-path argument.

Declare `NIOCertificateReloading` from swift-nio-extras and `GRPCServiceLifecycle` from grpc-swift-extras directly in the executable. Prime one `TimedCertificateReloader` per credential pair before constructing any transport:

```swift
let tlsConfig = config.scoped(to: "tls")
var reloaderConfig = try TimedCertificateReloader.Configuration(config: tlsConfig)
reloaderConfig.logger = logger
reloaderConfig.onCertificateLoadFailed = { failure in
    logger.warning("TLS certificate reload failed", metadata: ["error": "\(failure.error)"])
}
let certificateReloader = try TimedCertificateReloader.makeReloaderValidatingSources(
    configuration: reloaderConfig
)
```

The factory loads and validates the initial pair. Configuration construction does not start the reload loop. Own the reloader exactly once in the same `ServiceGroup` as the transports. Share it across service clients and the service listener only when the pair supports both purposes. Always construct a separate Temporal reloader with `config.scoped(to: "temporal.tls")`; it is a required lifecycle dependency, not an optional alternate path.

The transport factories read trust relative to their reader and take the reloader as a runtime dependency:

```swift
extension HTTP2ClientTransport.Posix.TransportSecurity {
    static func mTLS(config: ConfigReader, certificateReloader: any CertificateReloader) throws -> Self {
        let trustRootsPath = try config.requiredString(forKey: "trustRootsPath")
        return try .mTLS(certificateReloader: certificateReloader) {
            $0.trustRoots = .certificates([.file(path: trustRootsPath, format: .pem)])
            $0.serverCertificateVerification = .fullVerification
        }
    }
}

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

Import `Configuration`, `GRPCNIOTransportHTTP2`, and `NIOCertificateReloading` in these extension files. Server-side `.noHostnameVerification` still requires and verifies a client certificate against explicit trust; clients retain full server chain and hostname verification. An internal listener has no plaintext mode.

Put server connection settings in `HTTP2ServerTransport.Posix.Config+ConfigReader.swift`. For example, read `maxConnectionAgeSeconds` as `Duration` with a 300-second default and `connectionGraceTimeSeconds` with a 30-second default. Choose bounds that fit certificate lifetime and long-running RPCs; keep them below the operational renewal budget. Do not scatter duration conversions or validation guards through the commands.

The reloader changes the leaf pair used on new handshakes. It does not issue certificates, refresh a trust bundle, or re-authenticate existing connections. Failed updates retain the last usable pair and retry. Deployment owns Smallstep issuance/renewal, expiry monitoring, coordinated key publication, and CA rotation; see the delivery skill's [environment reference](../../delivering-swift-services/references/environment.md#transport-security-the-certificate-volume).

**Every client waits for the connection, bounded by a deadline.** A gRPC call made while its channel is not ready fails fast by default, the error a caller hits on the first request after an idle period, a peer restart, or a rolling deploy. Enable *wait-for-ready* once as a client-wide default rather than per call: a `ServiceConfig` with one `MethodConfig` whose name is the empty-service global bucket (`MethodConfig.Name(service: "")`, the fallback the transport returns for any method with no more specific entry) applies to every method, with `waitForReady: true` and a `timeout` so a genuinely-down upstream still fails instead of hanging the caller forever.

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

Pass it as `serviceConfig:` to every client's `.http2NIOPosix`, beside the mTLS factory. Do not reach for per-RPC `CallOptions` to set this: the generated call sites are scattered through use cases and adapters, and there is no single place to set a default `CallOptions`; `ServiceConfig` is that single place. The two are the same knob at different layers: the SDK unions a call's `CallOptions` with the method's `ServiceConfig`, filling only fields the call left unset, so `ServiceConfig` is the base default and `CallOptions` stays the per-RPC override for the rare call that needs a different timeout. The `GRPCServer` transport takes no service config, and Temporal uses its SDK’s client settings.

**Temporal has a dedicated credential scope.** Construct its transport with `temporal.tls` and a separate primed reloader. Use the Temporal SDK’s native reader for client/worker settings. Configure trust for the actual endpoint; the client validates its server hostname and CA chain. Both service and Temporal reloaders are required entries in the lifecycle when both are used.

## Temporal worker composition root

The worker is `worker run` on the executable, in `<Project>/Worker/` or `<Service>/Worker/`: `Worker` is a command group and `Run` the command whose `run()` is its own composition root, in the same section order as `serve` with a Worker section in place of the transport sections. `run` is the group's default, so `<executable> worker` alone starts it too; a group rather than a bare command so an operator command about the worker has somewhere to go beside `run`. It shares the executable's `Configuration/` extensions rather than carrying copies, and reads from `PostgresConfiguration` only the worker role:

```swift
struct Worker: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "worker",
        abstract: "The Temporal worker",
        subcommands: [Run.self],
        defaultSubcommand: Run.self
    )
}

struct Run: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "run",
        abstract: "Run the Temporal worker"
    )

    func run() async throws {
        // MARK: - Configuration
        // MARK: - Logging
        // MARK: - Infrastructure
        // MARK: - Composition
        // MARK: - Worker
        // MARK: - Lifecycle
    }
}
```

There is one image, the package's. The worker application runs it with `worker run` as its command, at the same tag as the serving application, because the two share one schema and one contract. The one thing `worker run` must not do is open a server or read the verifying key; keep those dependencies out of the worker command. In a monolith one worker runs every module's workflows, and its Composition builds each module's worker-scoped database and Activity service in module order.

The worker reaches its own database directly, as the worker role, and other services through their internal services as itself (see *Worker composition* in the orchestrating-temporal-workflows skill). Under Infrastructure, construct one `PostgresClient` from `postgres.worker`, and the long-lived gRPC and provider clients its Activities call, the gRPC clients with no interceptor, because the certificate on the connection is the credential. Under Composition, build `PostgresDatabase<Postgres<Module>WorkerScope>` over the client, the reconciliation use cases over it, the Core Activity service over those use cases, and the consumer adapters over the internal-service clients. Then create one `TemporalWorker`:

```swift
let temporalWorker = try TemporalWorker(
    configuration: .init(configReader: temporalConfig),
    target: .dns(
        host: temporalHost,
        port: temporalConfig.int(forKey: "port", default: 7233)
    ),
    transportSecurity: try .mTLS(config: temporalTLSConfig, certificateReloader: temporalCertificateReloader),
    activityContainers: ReservationActivities(service: activityService),
    workflows: [ReservationWorkflow.self],
    logger: logger
)
```

The configuration comes from the SDK's **own** reader, `TemporalWorker.Configuration(configReader:)`, handed the `temporal` scope, never a hand-built one; the serve side's client is the same shape, `TemporalClient.Configuration(configReader:)`. The SDK's keys become the environment contract: the worker *requires* `TEMPORAL_WORKER_NAMESPACE`, `_TASKQUEUE`, `_BUILDID`, `_CLIENT_IDENTITY`, and `_CLIENT_INSTRUMENTATION_SERVERHOSTNAME`, and reads `_HEARTBEATINTERVALMS` optionally; set it (60000 is a sane interval) so the worker reports liveness to the engine; the SDK's default disables heartbeats entirely. The client reads `TEMPORAL_CLIENT_NAMESPACE` and `_CLIENT_INSTRUMENTATION_SERVERHOSTNAME`. Only the dial target and the transport factory remain the composition root's job.

Add the worker, both certificate reloaders, and every long-lived dependency used by Activities directly to one `ServiceGroup` services array. Do not add a periodic database-to-Temporal reconciliation service. Temporal owns durable workflow execution.

A worker has no inbound user request to forward. It calls internal operations over mTLS with its mounted certificate/key pair; unusable files fail while priming the reloader, and the receiver admits peers through its configured CA trust. Internal handlers pass business input directly to use cases. The same applies to webhook handlers and scheduled jobs; see [identity-and-access.md](identity-and-access.md).

## Migrations at boot

`serve --migrate-database` applies migrations after logging bootstrap and before any long-lived infrastructure exists. The postgres scope is read once into the executable-local `PostgresConfiguration` above, which derives every connection the process makes. The owner client lives exactly as long as the apply, through a scoped helper that starts it in a task group and cancels it when the operation returns:

```swift
if migrateDatabase {
    try await PostgresClient.withClient(configuration: postgres.owner, logger: logger) { client in
        try await Migrations(client: client, configuration: postgres, logger: logger).run()
    }
}
```

`PostgresClient.withClient` comes from `PersistencePostgres`: it starts the client in a task group and cancels it when the operation returns or throws. `Migrations.run()` in `Database/Migrations.swift` adds the list explicitly in order: the role migrations first, `CreateServiceRole` before the others, reading each role's password from the configuration, then every module's `<Module>Migrations.migrations(internalRole:)` in module dependency order, and applies it:

```swift
await migrations.add(CreateServiceRole(role: configuration.serviceUser, password: try configuration.servicePassword, database: configuration.database))
await migrations.add(CreateInternalRole(role: configuration.internalUser, password: try configuration.internalPassword, database: configuration.database))
for migration in UsersMigrations.migrations(internalRole: configuration.internalUser) { await migrations.add(migration) }
for migration in CatalogMigrations.migrations(internalRole: configuration.internalUser) { await migrations.add(migration) }
try await migrations.apply(client: client, logger: logger, dryRun: false)
```

A service has one module, so its list is the roles and one module's migrations. The library refuses a reordered list, so a module that gains a migration appends it to its own list and never reorders another's; a new module appends its whole list after the existing ones. The long-lived clients the `ServiceGroup` owns are built from `postgres.service` and `postgres.internalService` and never hold owner credentials; the owner pair does sit in the serving container's environment, which is the accepted price of migrating in-process: the *process* that serves never connects with it.

The flag is the default because it needs no platform support: one container, one command, and the schema is current before the port opens. The alternative is a `migrate` subcommand running the same `Migrations.run()` and exiting, deployed as a one-shot job before the rollout, for a platform that orders jobs (an init container, a pre-deploy hook) or starts several replicas at once, where N containers racing the same list at boot is what the library's ordering check would refuse. Either way the rule holds: nothing serves an unmigrated schema, and only the migration client ever connects as the owner.

## Operator commands

An operation that must never be reachable over the network, a data repair, a one-off export, is a subcommand, run by an operator against the package's own database. It follows the boot-migration shape: short-lived, stdout logging, a scoped client around the work. Print exactly the value the operator needs on standard output and nothing else there, so a redirect captures it. The stack's CA issues process certificates, as described by the delivering-swift-services skill.
