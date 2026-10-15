# The worker

How the process that runs Workflows and Activities is composed, identified, configured, and connected, and the one Temporal piece `serve` builds. The serve composition root, configuration readers, and transport-security factories it builds on are the building-swift-services skill's [composition.md](../../building-swift-services/references/composition.md).

## Contents

- [The worker command](#the-worker-command)
- [The worker role and scope](#the-worker-role-and-scope)
- [Configuration](#configuration)
- [Temporal transport security](#temporal-transport-security)
- [The composition root](#the-composition-root)
- [Registering several containers](#registering-several-containers)
- [Calling other services](#calling-other-services)
- [The serve side](#the-serve-side)
- [Lifecycle](#lifecycle)
- [A monolith](#a-monolith)
- [Local development](#local-development)

## The worker command

The worker is `worker run` on the service executable: `Worker` a command group in `<Service>/Worker/Worker.swift` (`<Project>/Worker/` in a monolith), `Run` its composition root in `Run.swift`. `run` is the group's default, so `<executable> worker` starts it too; the group gives an operator command about the worker somewhere to go beside `run`.

```swift
import ArgumentParser

struct Worker: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "worker",
        abstract: "The Temporal worker",
        subcommands: [Run.self],
        defaultSubcommand: Run.self
    )
}
```

Add `Worker.self` to the root command's `subcommands`, beside `Serve.self`. `Run.run()` uses the serve root's section order with a Worker section in place of the transport sections:

```swift
// MARK: - Configuration
// MARK: - Logging
// MARK: - Infrastructure
// MARK: - Composition
// MARK: - Worker
// MARK: - Lifecycle
```

There is one image, the package's. The worker application runs it with `worker run` as its command, at the same tag as the serving application, because the two share one schema and one contract. `worker run` opens no server and reads no verifying key. It shares the executable's `Configuration/` extensions rather than carrying copies.

## The worker role and scope

The worker connects to its own service's database directly, as `<service>_worker` (`<project>_worker` in a monolith), with its own secret and a `USING (true)` policy. It never opens another service's database.

- **Migration.** `CreateWorkerRole` lives in `<Service>Postgres/Migrations/Role/` (the executable's `Database/Role/` in a monolith). Adding Temporal to an existing package appends it at the end of `Database/Migrations.swift`, after every migration already applied, followed by any policy that names the role; the migration library refuses a reordered list. The role's grants and policy are the building-swift-services skill's [migrations-and-rls.md](../../building-swift-services/references/migrations-and-rls.md#the-roles).

  ```swift
  await migrations.add(CreateReservationsTable())                                       // the last one already applied
  await migrations.add(CreateWorkerRole(role: configuration.workerUser, password: try configuration.workerPassword, database: configuration.database))
  try await migrations.apply(client: client, logger: logger, dryRun: false)
  ```

- **Scope.** `Postgres<Service>WorkerScope` in `<Service>Postgres/Scopes/` conforms to the scope protocols of the use cases the worker runs, and is the only scope that conforms to them. Those use cases take `input:` alone, since the user an Activity acts for is a `UUID` in its input, so `serve` cannot build them.

  ```swift
  package struct PostgresCatalogWorkerScope: PostgresScope, ReserveItemUseCaseScope, ReleaseReservationUseCaseScope, ConfirmReservationUseCaseScope {
      package let reservationRepository: any ReservationRepository

      package init(connection: PostgresConnection, logger: Logger) {
          self.reservationRepository = PostgresReservationRepository(connection: connection, logger: logger)
      }
  }
  ```

- **Configuration.** The worker reads from `PostgresConfiguration` only `postgres.worker`, whose password is read when asked for, so its environment carries neither the owner pair nor the serving roles' secrets. The migrating process reads the worker password too, for `CreateWorkerRole`.

## Configuration

The client and worker settings come from the SDK's own readers, `TemporalClient.Configuration(configReader:)` and `TemporalWorker.Configuration(configReader:)`, handed the `temporal` scope; never hand-build either. Keep the SDK's key names and units:

```dotenv
POSTGRES_WORKER_PASSWORD=…                                # worker run, and the migrating process
TEMPORAL_HOST=temporal
TEMPORAL_PORT=7233
TEMPORAL_TLS_CERTIFICATE_PATH=/run/temporal-tls/cert.pem
TEMPORAL_TLS_PRIVATE_KEY_PATH=/run/temporal-tls/key.pem
TEMPORAL_TLS_TRUST_ROOTS_PATH=/run/temporal-tls/ca.pem
TEMPORAL_TLS_REFRESH_INTERVAL_SECONDS=60
TEMPORAL_CLIENT_NAMESPACE=production                      # serve: the SDK's client keys
TEMPORAL_CLIENT_INSTRUMENTATION_SERVERHOSTNAME=temporal
TEMPORAL_TASK_QUEUE=catalog                               # serve: the application's key, the queue its clients start on
TEMPORAL_WORKER_NAMESPACE=production                      # worker: the SDK's worker keys
TEMPORAL_WORKER_TASKQUEUE=catalog
TEMPORAL_WORKER_BUILDID=production
TEMPORAL_WORKER_CLIENT_IDENTITY=catalog-worker
TEMPORAL_WORKER_CLIENT_INSTRUMENTATION_SERVERHOSTNAME=temporal
TEMPORAL_WORKER_HEARTBEATINTERVALMS=60000                 # worker liveness; the SDK default disables it
```

- `serve` starts Workflows on the application key `temporal.taskQueue`; the worker polls the SDK's `temporal.worker.taskqueue`. Derive both defaults from one value in the application defaults provider, and document that overrides must agree.
- Required SDK keys may be satisfied by application defaults; otherwise a missing one fails at startup, not on the first task. Set the heartbeat interval wherever liveness reporting is required.
- Only the dial target and the transport factory remain the composition root's job.

## Temporal transport security

Whether Temporal gets its own pair is the project's decision; record it in `AGENTS.md`:

- **Its own pair** (the worked example below): a `temporal.tls` scope with its own certificate and key, trust bundle, primed `TimedCertificateReloader`, and renewer. Choose it when Temporal's trust differs from the services': one Temporal server shared by several environments, a separate CA, or a hosted Temporal. Then never fall back to the service `tls` pair.
- **The process's pair**: Temporal's transport takes the same `tls` reader and reloader as the process's other connections. It suits a Temporal server per environment that trusts the same CA. A worker whose Activities call no other service still mounts one pair.

Either way the connection is mTLS with an explicit trust bundle and full server verification, and each reloader runs once. The `.mTLS(config:certificateReloader:)` factory is the client one in [transport-security.md](../../building-swift-services/references/transport-security.md#transport-security-factories); `TemporalClient` and `TemporalWorker` take the same `HTTP2ClientTransport.Posix.TransportSecurity`.

```swift
let temporalTLSConfig = config.scoped(to: "temporal.tls")
var temporalReloaderConfig = try TimedCertificateReloader.Configuration(config: temporalTLSConfig)
temporalReloaderConfig.logger = logger
temporalReloaderConfig.onCertificateLoadFailed = { failure in
    logger.warning("Temporal TLS certificate reload failed", metadata: ["error": "\(failure.error)"])
}
let temporalCertificateReloader = try TimedCertificateReloader.makeReloaderValidatingSources(
    configuration: temporalReloaderConfig
)
```

Priming validates the initial pair, so unusable files fail at startup. The reloader runs once, in the process's `ServiceGroup`.

## The composition root

A complete `Run.swift` for a worker whose Activities use their own database, an email provider, and another service's internal contract:

```swift
import ArgumentParser
import CatalogCore
import CatalogGRPC
import CatalogPostgres
import CatalogResend
import CatalogWorkflows
import Configuration
import GRPCCore
import GRPCNIOTransportHTTP2
import GRPCServiceLifecycle
import Logging
import LoggingLoki
import NIOCertificateReloading
import PersistencePostgres
import PostgresNIO
import Resend
import ServiceLifecycle
import Temporal
import UnixSignals

struct Run: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "run",
        abstract: "Run the Temporal worker"
    )

    func run() async throws {
        // MARK: - Configuration
        let config = ConfigReader(providers: [EnvironmentVariablesProvider(), InMemoryProvider.applicationDefaults])

        // MARK: - Logging
        let lokiProcessor = LokiLogProcessor(
            configuration: try LokiLogProcessorConfiguration(config: config.scoped(to: "loki"))
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
        let logger = Logger(label: "catalog-worker")

        // MARK: - Infrastructure
        // The service pair, for the orders internal contract.
        let tlsConfig = config.scoped(to: "tls")
        var certificateReloaderConfig = try TimedCertificateReloader.Configuration(config: tlsConfig)
        certificateReloaderConfig.logger = logger
        certificateReloaderConfig.onCertificateLoadFailed = { failure in
            logger.warning("TLS certificate reload failed", metadata: ["error": "\(failure.error)"])
        }
        let certificateReloader = try TimedCertificateReloader.makeReloaderValidatingSources(
            configuration: certificateReloaderConfig
        )

        // This service's own database, as the worker role alone.
        let postgres = try PostgresConfiguration(config: config.scoped(to: "postgres"))
        let postgresClient = try PostgresClient(configuration: postgres.worker, backgroundLogger: logger)

        // Another service through its internal descriptor: mTLS, no interceptor, no token.
        let ordersConfig = config.scoped(to: "grpc.orders")
        let ordersClient = GRPCClient(
            transport: try .http2NIOPosix(
                target: .dns(
                    host: try ordersConfig.requiredString(forKey: "host"),
                    port: try ordersConfig.requiredInt(forKey: "port")
                ),
                transportSecurity: try .mTLS(config: tlsConfig, certificateReloader: certificateReloader),
                serviceConfig: .defaults
            )
        )

        let resendClient = try ResendClient(config: config.scoped(to: "resend"))

        let temporalConfig = config.scoped(to: "temporal")
        let temporalHost = try temporalConfig.requiredString(forKey: "host")
        let temporalTLSConfig = config.scoped(to: "temporal.tls")
        var temporalReloaderConfig = try TimedCertificateReloader.Configuration(config: temporalTLSConfig)
        temporalReloaderConfig.logger = logger
        temporalReloaderConfig.onCertificateLoadFailed = { failure in
            logger.warning("Temporal TLS certificate reload failed", metadata: ["error": "\(failure.error)"])
        }
        let temporalCertificateReloader = try TimedCertificateReloader.makeReloaderValidatingSources(
            configuration: temporalReloaderConfig
        )

        // MARK: - Composition
        // The worker's use cases run on the worker database alone: only its scope conforms to their
        // scopes. Orders is reached through its internal contract as this process.
        let database = PostgresDatabase<PostgresCatalogWorkerScope>(client: postgresClient, logger: logger)
        let activityService = ReservationActivityService(
            reserveUseCase: ReserveItemUseCase(database: database, logger: logger),
            releaseUseCase: ReleaseReservationUseCase(database: database, logger: logger),
            confirmUseCase: ConfirmReservationUseCase(
                database: database,
                orders: GRPCOrderClient(client: ordersClient),
                logger: logger
            ),
            confirmationEmailSender: ResendConfirmationEmailSender(
                client: resendClient,
                templateId: try config.scoped(to: "email").requiredString(forKey: "confirmationTemplateId")
            )
        )

        // MARK: - Worker
        let temporalWorker = try TemporalWorker(
            configuration: .init(configReader: temporalConfig),
            target: .dns(host: temporalHost, port: temporalConfig.int(forKey: "port", default: 7233)),
            transportSecurity: try .mTLS(config: temporalTLSConfig, certificateReloader: temporalCertificateReloader),
            activityContainers: ReservationActivities(service: activityService),
            workflows: [ReservationWorkflow.self],
            logger: logger
        )

        // MARK: - Lifecycle
        let serviceGroup = ServiceGroup(
            services: [
                lokiProcessor,
                postgresClient,
                certificateReloader,
                temporalCertificateReloader,
                ordersClient,
                temporalWorker,
            ],
            gracefulShutdownSignals: [.sigint, .sigterm],
            logger: logger
        )

        logger.info("Starting Temporal worker")
        try await serviceGroup.run()
    }
}
```

A worker whose Activities call no other service drops the `tls` reloader and the gRPC client. The provider adapter (`ResendConfirmationEmailSender`) and the consumer adapter (`GRPCOrderClient`) implement Core ports and are injected into the Activity service, never into the container; see [activities.md](activities.md#activities).

## Registering several containers

`activityContainers:` is variadic. List every container, and every Workflow in `workflows:`:

```swift
let temporalWorker = try TemporalWorker(
    configuration: .init(configReader: temporalConfig),
    target: .dns(host: temporalHost, port: temporalConfig.int(forKey: "port", default: 7233)),
    transportSecurity: try .mTLS(config: temporalTLSConfig, certificateReloader: temporalCertificateReloader),
    activityContainers: fulfillmentActivities, subscriptionActivities,
    workflows: [FulfillmentWorkflow.self, SubscriptionWorkflow.self],
    logger: logger
)
```

Every registered container shares one Activity-name space; a name two containers share silently runs one container's Activity for the other's Workflow. The test that refuses that is in [testing.md](testing.md#activity-names-are-unique). A child Workflow is registered like any other.

## Calling other services

A worker calls another service through that service's `<Entity>InternalService` descriptor, over mTLS with its mounted service pair, with no bearer and no application authentication interceptor; the certificate on the connection is the credential. Build one long-lived `GRPCClient` per upstream, wrap it in the consumer adapter that implements the Core port, and own the client in the `ServiceGroup`.

The receiver's internal handler passes business input to an input-only use case, which enforces its own invariants over that service's unscoped database. The user a Workflow acts for is a `UUID` in the input, resource data, never a `subject:` and never a token. Authorize a user-triggered Workflow at the initiating request and persist the user id and durable business input, not a JWT that can expire mid-run. See the building-swift-services skill's [identity-and-access.md](../../building-swift-services/references/identity-and-access.md).

## The serve side

`serve` builds one long-lived `TemporalClient` and injects the Workflow-client adapter into the use cases that start or signal. It runs no Workflow definitions and no Activities. Note the argument order: `TemporalClient` takes `target:` and `transportSecurity:` before `configuration:`, where `TemporalWorker` takes `configuration:` first.

```swift
// MARK: - Infrastructure
let temporalConfig = config.scoped(to: "temporal")
let temporalHost = try temporalConfig.requiredString(forKey: "host")
let temporalTLSConfig = config.scoped(to: "temporal.tls")
// temporalCertificateReloader, primed as in Temporal transport security
let temporalClient = try TemporalClient(
    target: .dns(host: temporalHost, port: temporalConfig.int(forKey: "port", default: 7233)),
    transportSecurity: try .mTLS(config: temporalTLSConfig, certificateReloader: temporalCertificateReloader),
    configuration: .init(configReader: temporalConfig),
    logger: logger
)
let reservationWorkflowClient = TemporalReservationWorkflowClient(
    client: temporalClient,
    taskQueue: try temporalConfig.requiredString(forKey: "taskQueue")
)
```

Add `temporalCertificateReloader` and `temporalClient` to serve's `ServiceGroup`.

## Lifecycle

One `ServiceGroup` with graceful shutdown owns the worker, its Postgres client, every long-lived gRPC and provider client its Activities use, the Temporal reloader, and the service `tls` reloader when Activities call another service. A borrowed SDK singleton such as `HTTPClient.shared` follows the exception recorded in `AGENTS.md`. Add no periodic database-to-Temporal reconciliation service.

## A monolith

- One `worker run` runs every module's Workflows, on one task queue, unless a module needs isolation (its Activities could starve the others', or it must scale separately); that module gets its own task queue and its own `TemporalWorker` in the same `ServiceGroup`, recorded in `AGENTS.md`.
- One role, `<project>_worker`, and one `PostgresClient` for it; one `PostgresDatabase<Postgres<Module>WorkerScope>` per module over that client, and each module's Activity service, built in module dependency order.
- Workflow IDs carry the module: `<project>-<module>-<feature>-<id>`.
- Activity names are unique across every module's containers, and the uniqueness test registers all of them.
- An Activity service reaches another module only through its own module's Core port, satisfied in the composition root by an adapter over the other module's use case, exactly as `serve` satisfies it; never by calling that module's use case or database directly.

## Local development

A local worker connects to Temporal over mTLS like everywhere else, with its Temporal pair from the local development CA; there is no plaintext mode. Issuing local certificates is the delivering-swift-services skill's [certificates.md](../../delivering-swift-services/references/certificates.md).
