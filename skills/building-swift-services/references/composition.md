# Composition roots

## Contents

- Command tree
- Environment configuration
- Serve composition root
- Transport security factories
- Temporal worker composition root
- Migration composition root
- Operator commands

## Command tree

Name the executable target after the service, not `<Service>Server`. The root command defaults to serving, and there is no migrate subcommand: migrations are a `serve` flag, applied in-process before the server binds (see *Migrations at boot* below).

```text
catalog                          # defaults to serve
catalog serve
catalog serve --migrate-database # apply pending migrations, then serve
catalog worker run               # only with Temporal — the worker's composition root, same executable
```

```swift
@main
struct Catalog: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "catalog",
        abstract: "Catalog Service",
        subcommands: [
            Serve.self,
            Worker.self,   // only with Temporal
        ],
        defaultSubcommand: Serve.self
    )
}
```

Put commands in `<Service>/<Command>/`; the migration list lives at `<Service>/Database/Migrations.swift`.

## Environment configuration

Start with `ConfigReader(provider: EnvironmentVariablesProvider())`, then scope by concern. Swift Configuration transforms camel-case scoped keys into variables:

```dotenv
POSTGRES_HOST=localhost
POSTGRES_PORT=5432
POSTGRES_USER=…                      # the instance's owner, verbatim — migrations only
POSTGRES_PASSWORD=…
POSTGRES_DB=<project>_catalog
POSTGRES_SERVICE_PASSWORD=…          # <service>_service, the tenant-scoped role; the name defaults
POSTGRES_INTERNAL_PASSWORD=…         # <service>_internal — only a tenant service
POSTGRES_WORKER_PASSWORD=…           # <service>_worker — only the worker's environment
GRPC_SERVER_HOST=0.0.0.0
GRPC_SERVER_PORT=50051
GRPC_ACCOUNTS_HOST=accounts          # one scope per upstream, required
GRPC_ACCOUNTS_PORT=50051
TLS_CERTIFICATE_PATH=/run/tls/cert.pem
TLS_PRIVATE_KEY_PATH=/run/tls/key.pem
TLS_TRUST_ROOTS_PATH=/run/tls/ca.pem
JWT_PUBLIC_KEY_PATH=/run/secrets/jwt-public
TEMPORAL_HOST=temporal
TEMPORAL_PORT=7233
TEMPORAL_CLIENT_NAMESPACE=production                      # serve — the SDK's own client keys
TEMPORAL_CLIENT_INSTRUMENTATION_SERVERHOSTNAME=temporal
TEMPORAL_WORKER_NAMESPACE=production                      # worker — the SDK's own worker keys
TEMPORAL_WORKER_TASKQUEUE=catalog
TEMPORAL_WORKER_BUILDID=production
TEMPORAL_WORKER_CLIENT_IDENTITY=catalog-worker
TEMPORAL_WORKER_CLIENT_INSTRUMENTATION_SERVERHOSTNAME=temporal
TEMPORAL_WORKER_HEARTBEATINTERVALMS=60000                 # worker liveness; the SDK default disables
LOKI_URL=http://loki:3100
LOG_LEVEL=info
```

Give each configuration an `init(config:)` extension in the executable's `Configuration` folder — `PostgresConfiguration.swift`, `TransportSecurity+ConfigReader.swift`, `EdDSA.PublicKey+ConfigReader.swift`, and so on. A small extension duplicated per service, not a shared package: configuration is where services legitimately differ, which is why it is the one thing the shared packages deliberately do not carry.

```swift
struct PostgresConfiguration: Sendable {
    let host: String; let port: Int; let database: String
    let serviceUser: String                                   // the tenant-scoped role
    let internalUser: String                                  // only a tenant service
    let workerUser: String                                    // only with Temporal
    private let config: ConfigReader

    init(config: ConfigReader) throws {
        self.host = try config.requiredString(forKey: "host")
        self.port = config.int(forKey: "port", default: 5432)
        self.database = config.string(forKey: "db", default: "<project>_<service>")
        self.serviceUser = config.string(forKey: "serviceUser", default: "<service>_service")
        self.internalUser = config.string(forKey: "internalUser", default: "<service>_internal")
        self.workerUser = config.string(forKey: "workerUser", default: "<service>_worker")
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

Each connection reads its password when it is asked for rather than in `init`. That is what lets one type serve every command: `serve` reads the service and internal roles, `serve --migrate-database` the owner too, and `worker run` the worker role alone — so the worker's environment carries neither the owner pair nor the serving roles' secrets, and a missing secret still fails at startup, naming the key, because every command builds its clients before its `ServiceGroup` runs. The password properties are exposed so the role migrations can read them.

Require hosts and secrets; default the constants. A constant is anything that never varies by deployment: the standard mount paths (`/run/tls/{cert,key,ca}.pem`, `/run/secrets/jwt-public`), well-known ports, the listen address, the log level, and the service's *own identity* — its database name and its role names, all derivable from the service's name by convention. Baking these into the `+ConfigReader` extensions (the environment always overrides a default) shrinks every deployment's variable set to topology and secrets. Require an upstream's host rather than defaulting it: a process that quietly dials `localhost` in a container reports a misconfiguration as a connection failure minutes later, at the first request, instead of at startup. And know what each library treats as required — a value your code used to default may be *required* by a stock configuration reader, and the missing variable then crash-loops the process at boot (the Temporal worker's task queue is the canonical example).

Key material — signing keys, certificates — is configured as a path and the file is opened here, in the composition root, never in a library. A path is the form NIOSSL and grpc-swift already take credentials in, it keeps a private key out of the environment, and it fails at startup naming the path. The rationale is in [identity-and-access.md](identity-and-access.md), *Key material in configuration*.

Where the values come from in a running environment is the delivering-swift-services skill's subject.

## Serve composition root

Use these section comments in this order:

```swift
func run() async throws {
    // MARK: - Configuration
    // MARK: - Logging
    // MARK: - Infrastructure
    // MARK: - Composition
    // MARK: - gRPC
    // MARK: - Lifecycle
}
```

**Logging.** Bootstrap the logging system inline — never behind a shared helper or module. Build one in-process log shipper, then `LoggingSystem.bootstrap` a `MultiplexLogHandler` of `StreamLogHandler.standardOutput` and the shipper's handler, so every line reaches both the container's stdout and the aggregator. Pass the service name as the handler's service label, and `<Project>Authentication`'s metadata providers as the bootstrap's, so every log line inside a request carries the bound caller — `user_id`, and `service_name` on a service that admits processes — with no handler naming them. The default aggregator is Grafana Loki through `swift-log-loki`; substituting another in-process shipper changes only this block.

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
    metadataProvider: .multiplex([.user, .service])   // `.user` alone on a service with no internal service
)
let logger = Logger(label: "catalog")
```

**Infrastructure.** Construct one `PostgresClient` per role the process connects as — the service role, and on a tenant service the internal role — the token verifier from the mounted public key, one `GRPCClient` per upstream, and — with Temporal — one `TemporalClient`. Scope the transport-security reader once:

```swift
let tlsConfig = config.scoped(to: "tls")
let serviceClient = PostgresClient(configuration: postgres.service, backgroundLogger: logger)
let internalClient = PostgresClient(configuration: postgres.internalService, backgroundLogger: logger)
let userAuthenticator = await JWTAuthenticator<UserIdentity>(publicKey: try EdDSA.PublicKey(config: config.scoped(to: "jwt")))
```

**Composition.** Construct one `PostgresDatabase` per database — `PostgresDatabase<Postgres<Service>Scope>(client:logger:)` over the service client, `PostgresDatabase<Postgres<Service>InternalScope>(client:logger:)` over the internal one — then policies, use cases (each over the database its scope admits, passing `logger`), workflow-client adapters, and one gRPC service implementation per proto service. Say in a comment which database each use case runs on and why, because that sentence is the authorization design.

**gRPC.** Construct one server with every proto service, and apply each interceptor to the service whose audience it identifies:

```swift
let serverConfig = config.scoped(to: "grpc.server")
let server = GRPCServer(
    transport: .http2NIOPosix(
        address: .ipv4(
            host: serverConfig.string(forKey: "host", default: "0.0.0.0"),
            port: serverConfig.int(forKey: "port", default: 50051)
        ),
        transportSecurity: try .mTLS(config: tlsConfig)
    ),
    services: [itemPublicService, itemService, itemInternalService],
    interceptorPipeline: [
        .apply(
            BearerAuthenticationInterceptor(authenticator: userAuthenticator),
            to: .services([<Organization>_Catalog_V1_ItemService.descriptor])
        ),
        .apply(
            UserSettingsInterceptor(),   // only a tenant service: the bound user becomes the tenant setting
            to: .services([<Organization>_Catalog_V1_ItemService.descriptor])
        ),
        .apply(
            CertificateAuthenticationInterceptor(authenticator: ServiceAuthenticator()),
            to: .services([<Organization>_Catalog_V1_ItemInternalService.descriptor])
        ),
    ]
)
```

The public service gets nothing. `BearerAuthenticationInterceptor` is in `AuthenticationGRPC`; `UserSettingsInterceptor` in `<Project>Persistence`, after the bearer interceptor because it reads what that one bound; `CertificateAuthenticationInterceptor` is in `AuthenticationGRPCNIOTransport`, which a service links only when it has an internal service to protect, because only the NIO Posix transport exposes the peer certificate.

**Lifecycle.** Own every long-lived thing with ServiceLifecycle:

```swift
let serviceGroup = ServiceGroup(
    services: [lokiProcessor, serviceClient, internalClient, accountsClient, server],
    gracefulShutdownSignals: [.sigint, .sigterm],
    logger: logger
)
try await serviceGroup.run()
```

When the service uses Temporal, construct one long-lived `TemporalClient` in `serve`, inject a `<Feature>WorkflowClient` adapter into Core use cases, and include the client in `ServiceGroup`. Do not run workflow definitions or Activity implementations in the gRPC server process.

## Transport security factories

Every connection is mutually authenticated, in both directions, with the one leaf certificate the process was issued (see *Transport security* in the delivering-swift-services skill). The factories live in the executable's `Configuration` folder as `TransportSecurity+ConfigReader.swift`, one per direction, on grpc-swift's own types — so a call site reads exactly like the library's `.plaintext` did, and there is no struct to carry two values and no mode to switch:

```swift
extension HTTP2ServerTransport.Posix.TransportSecurity {
    /// A server cannot know a client's hostname, so it checks only that the client's certificate
    /// chains to the CA — grpc's default for mTLS.
    static func mTLS(config: ConfigReader) throws -> Self {
        let certificateChain: [TLSConfig.CertificateSource] = [
            .file(path: try config.requiredString(forKey: "certificatePath"), format: .pem)
        ]
        let privateKey: TLSConfig.PrivateKeySource = .file(
            path: try config.requiredString(forKey: "privateKeyPath"),
            format: .pem
        )
        let trustRoots: TLSConfig.TrustRootsSource = .certificates([
            .file(path: try config.requiredString(forKey: "trustRootsPath"), format: .pem)
        ])
        return .mTLS(certificateChain: certificateChain, privateKey: privateKey) { tls in
            tls.trustRoots = trustRoots
        }
    }
}

extension HTTP2ClientTransport.Posix.TransportSecurity {
    /// A client knows exactly whom it dialled, so it checks the name as well as the chain.
    static func mTLS(config: ConfigReader) throws -> Self {
        // the same three sources
        return .mTLS(certificateChain: certificateChain, privateKey: privateKey) { tls in
            tls.trustRoots = trustRoots
            tls.serverCertificateVerification = .fullVerification
        }
    }
}
```

The reader is scoped to `tls`, so the operator sets `TLS_CERTIFICATE_PATH`, `TLS_PRIVATE_KEY_PATH`, and `TLS_TRUST_ROOTS_PATH`. A missing one fails at startup naming the key. Every `GRPCClient`, and the `TemporalClient` and `TemporalWorker` when the Temporal server runs inside the stack, take the client factory; the `GRPCServer` takes the server one. Do not share the file through a package: the shape is eight lines a service owns, and configuration is where services differ.

**Every client waits for the connection, bounded by a deadline.** A gRPC call made while its channel is not ready fails fast by default — the error a caller hits on the first request after an idle period, a peer restart, or a rolling deploy. Enable *wait-for-ready* once as a client-wide default rather than per call: a `ServiceConfig` with one `MethodConfig` whose name is the empty-service global bucket (`MethodConfig.Name(service: "")` — the fallback the transport returns for any method with no more specific entry) applies to every method, with `waitForReady: true` and a `timeout` so a genuinely-down upstream still fails instead of hanging the caller forever.

```swift
extension ServiceConfig {
    static let defaults = ServiceConfig(
        methodConfig: [
            MethodConfig(
                names: [MethodConfig.Name(service: "")],  // "" — every method of every service
                waitForReady: true,
                timeout: .seconds(15)
            )
        ]
    )
}
```

Pass it as `serviceConfig:` to every client's `.http2NIOPosix`, beside the mTLS factory. Do not reach for per-RPC `CallOptions` to set this — the generated call sites are scattered through use cases and adapters, and there is no single place to set a default `CallOptions`; `ServiceConfig` is that single place. The two are the same knob at different layers: the SDK unions a call's `CallOptions` with the method's `ServiceConfig`, filling only fields the call left unset — so `ServiceConfig` is the base default and `CallOptions` stays the per-RPC override for the rare call that needs a different timeout. The `GRPCServer` transport takes no service config, and a managed engine's client (below) carries its own.

**A managed workflow engine or any external endpoint is outside the stack.** The client factory is wrong on both counts for it — its trust roots are the internal CA, and the external frontend chains to a public one. Such a client uses TLS with the system trust roots and the provider's own credential, configured in that provider's scope beside its address:

```swift
let temporalClient = try TemporalClient(
    target: .dns(host: temporalHost, port: 7233),        // the provider's endpoint
    transportSecurity: .tls { tls in tls.trustRoots = .systemDefault },
    configuration: .init(
        instrumentation: .init(serverHostname: temporalHost),
        namespace: temporalNamespace,
        // the API key, from the `temporal` scope, through whichever option the pinned SDK exposes
    ),
    logger: logger
)
```

Keep the two concerns in two scopes: `tls` is who the process is inside the stack; `temporal` is where the workflow engine is and how it is reached. Prefer an API key over registering a CA with the provider: it rotates from the provider's console and binds no vendor setting to the stack's CA.

## Temporal worker composition root

The worker is `worker run` on the service executable, in `<Service>/Worker/`: `Worker` is a command group and `Run` the command whose `run()` is its own composition root, in the same section order as `serve`. `run` is the group's default, so `<service> worker` alone starts it too; a group rather than a bare command so an operator command about the worker has somewhere to go beside `run`. It shares the executable's `Configuration/` extensions rather than carrying copies, and reads from `PostgresConfiguration` only the worker role:

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

There is one image, the service's. The worker application runs it with `worker run` as its command, at the same tag as the service application, because the two share one schema and one contract. The one thing `worker run` must not do is open the gRPC server or read the verifying key; that is a fact of the command, kept by review, where it was once a fact of the manifest.

The worker reaches its own service's database directly, as the worker role, and other services through their internal services as itself (see *Worker composition* in the orchestrating-temporal-workflows skill). Under Infrastructure, construct one `PostgresClient` from `postgres.worker`, and the long-lived gRPC and provider clients its Activities call — the gRPC clients with no interceptor, because the certificate on the connection is the credential. Under Composition, build `PostgresDatabase<Postgres<Service>WorkerScope>` over the client, the reconciliation use cases over it, the Core Activity service over those use cases, and the consumer adapters over the internal-service clients. Then create one `TemporalWorker`:

```swift
let temporalWorker = try TemporalWorker(
    configuration: .init(configReader: temporalConfig),
    target: .dns(
        host: temporalHost,
        port: temporalConfig.int(forKey: "port", default: 7233)
    ),
    transportSecurity: try .mTLS(config: tlsConfig),
    activityContainers: ReservationActivities(service: activityService),
    workflows: [ReservationWorkflow.self],
    logger: logger
)
```

The configuration comes from the SDK's **own** reader — `TemporalWorker.Configuration(configReader:)`, handed the `temporal` scope — never a hand-built one; the serve side's client is the same shape, `TemporalClient.Configuration(configReader:)`. The SDK's keys become the environment contract: the worker *requires* `TEMPORAL_WORKER_NAMESPACE`, `_TASKQUEUE`, `_BUILDID`, `_CLIENT_IDENTITY`, and `_CLIENT_INSTRUMENTATION_SERVERHOSTNAME`, and reads `_HEARTBEATINTERVALMS` optionally — set it (60000 is a sane interval) so the worker reports liveness to the engine; the SDK's default disables heartbeats entirely. The client reads `TEMPORAL_CLIENT_NAMESPACE` and `_CLIENT_INSTRUMENTATION_SERVERHOSTNAME`. Only the dial target and the transport factory remain the composition root's job.

Add the worker and every long-lived dependency used by Activities to one `ServiceGroup`. Do not add a periodic database-to-Temporal reconciliation service. Temporal owns durable workflow execution.

A worker has no inbound request to forward, so it speaks as itself, and its certificate is how (see *Processes: the certificate is the credential* in [identity-and-access.md](identity-and-access.md)). There is nothing to exchange at startup and no credential to read: a worker whose leaf is missing fails in the transport factory naming the path, and one whose leaf lacks the URI SAN is refused at the first internal call as a peer the receiver cannot name. The same shape applies to any process that calls as itself — a webhook-handling `serve`, a scheduled job.

## Migrations at boot

`serve --migrate-database` applies migrations after logging bootstrap and before any long-lived infrastructure exists. The postgres scope is read once into the executable-local `PostgresConfiguration` above, which derives every connection the process makes. The owner client lives exactly as long as the apply, through a scoped helper that starts it in a task group and cancels it when the operation returns:

```swift
if migrateDatabase {
    try await PostgresClient.withClient(configuration: postgres.owner, logger: logger) { client in
        try await Migrations(client: client, configuration: postgres, logger: logger).run()
    }
}
```

`PostgresClient.withClient` comes from `PersistencePostgres`: it starts the client in a task group and cancels it when the operation returns or throws. `Migrations.run()` adds the list explicitly in order — `CreateServiceRole` first, then the other role migrations and the tables — reading each role's password from the configuration, and applies it. The long-lived clients the `ServiceGroup` owns are built from `postgres.service` and `postgres.internalService` and never hold owner credentials; the owner pair does sit in the serving container's environment, which is the accepted price of migrating in-process — the *process* that serves never connects with it.

## Operator commands

An operation that must never be reachable over the network — a data repair, a one-off export — is a subcommand, run by an operator against the service's own database. It follows the boot-migration shape: short-lived, stdout logging, a scoped client around the work. Print exactly the value the operator needs on standard output and nothing else there, so a redirect captures it. There is no credential-issuing command any more: a process's credential is its certificate, issued by the stack's CA (the delivering-swift-services skill).
