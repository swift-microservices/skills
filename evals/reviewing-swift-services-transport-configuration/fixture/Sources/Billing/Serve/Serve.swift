import ArgumentParser
import Configuration
import GRPCNIOTransportHTTP2
import Logging
import NIOCertificateReloading
import ServiceLifecycle
import Temporal

struct Serve: AsyncParsableCommand {
    func run() async throws {
        let config = ConfigReader(providers: [
            InMemoryProvider.applicationDefaults,
            EnvironmentVariablesProvider(),
        ])
        let logger = Logger(label: "billing")
        let tls = config.scoped(to: "tls")
        let temporal = config.scoped(to: "temporal")
        let temporalTLS = config.scoped(to: "temporal.tls")
        let refreshInterval = tls.int(forKey: "refreshIntervalSeconds", default: 60)
        guard refreshInterval > 0 else {
            throw ValidationError("TLS refresh interval must be positive.")
        }
        var reloaderConfig = try TimedCertificateReloader.Configuration(config: tls)
        reloaderConfig.logger = logger
        let reloader = try TimedCertificateReloader.makeReloaderValidatingSources(configuration: reloaderConfig)
        let server = try makeServer(transportSecurity: .mTLS(config: tls, certificateReloader: reloader))
        let accounts = try makeAccountsClient(transportSecurity: .mTLS(
            config: tls,
            certificateReloader: reloader,
            defaultTrustRootsPath: "/run/tls/ca.pem"
        ))
        let temporalClient = try makeTemporalClient(
            configuration: TemporalClient.Configuration(configReader: temporal),
            transportSecurity: .mTLS(
                config: temporalTLS,
                certificateReloader: reloader,
                defaultTrustRootsPath: "/run/temporal-tls/ca.pem"
            )
        )
        try await ServiceGroup(
            services: [reloader, server, accounts, temporalClient],
            gracefulShutdownSignals: [.sigint, .sigterm],
            logger: logger
        ).run()
    }
}
