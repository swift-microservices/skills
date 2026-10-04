# Configuring applications and libraries

Keep provider selection in the executable and configuration parsing close to the type being configured. `Serve` and `Run` assemble dependencies and lifecycle; they do not validate or interpret settings.

## Contents

- Prefer native readers
- Supply application defaults
- Extend types without a reader
- Names, units, and validation
- Library adoption

## Prefer native readers

Check the pinned library's configuration API before writing an adapter. Hummingbird's `ApplicationConfiguration(reader:)`, Temporal's client and worker `Configuration(configReader:)`, and Valkey's `ValkeyClientConfiguration(configReader:)` already support Swift Configuration in compatible releases. Enable required package traits, such as Hummingbird's `ConfigurationSupport`, explicitly.

Pass the concern's scoped reader to the library. Preserve the library's relative keys, units, and further internal scopes; do not invent aliases that look more consistent but stop matching its API. A native reader may configure only part of an object: Valkey's reader does not select the endpoint or enable TLS. Check what remains the application's responsibility.

## Supply application defaults

The executable creates the provider hierarchy once. Earlier providers take precedence:

```swift
let config = ConfigReader(providers: [
    EnvironmentVariablesProvider(),
    InMemoryProvider.applicationDefaults,
])
```

Put deployment conventions in `Configuration/InMemoryProvider+ApplicationDefaults.swift`:

```swift
import Configuration

extension InMemoryProvider {
    static var applicationDefaults: Self {
        let taskQueue: ConfigValue = "catalog"
        return .init(values: [
            "tls.certificatePath": "/run/tls/cert.pem",
            "tls.privateKeyPath": "/run/tls/key.pem",
            "tls.trustRootsPath": "/run/tls/ca.pem",
            "jwt.publicKeyPath": "/run/secrets/jwt-public",
            "postgres.db": "acme_catalog",
            "postgres.serviceUser": "catalog_service",
            "postgres.internalUser": "catalog_internal",
            "postgres.workerUser": "catalog_worker",
            "grpc.server.host": "0.0.0.0",
            "grpc.server.port": 50051,
            "loki.url": "http://localhost:3100",
            "temporal.tls.certificatePath": "/run/temporal-tls/cert.pem",
            "temporal.tls.privateKeyPath": "/run/temporal-tls/key.pem",
            "temporal.tls.trustRootsPath": "/run/temporal-tls/ca.pem",
            "temporal.taskQueue": taskQueue,
            "temporal.worker.taskqueue": taskQueue,
        ])
    }
}
```

Only include scopes the application uses. The application provider owns TLS/JWT mount paths, database/role names, listener bindings, task queues, application URLs, and other deployment conventions. Adapters consume these with required accessors; the provider satisfies an omitted environment override. A local wrapper such as `PostgresConfiguration` owns role selection and parsing, not a second copy of deployment defaults. A recorded project exception in `AGENTS.md` may choose another owner. Do not pass `defaultPath` or `certificateDirectory` arguments to reusable initializers. Environment variables still override these values.

A library's ordinary tuning defaults can stay in its reader or designated initializer. Do not repeat every library default in the application provider. Require topology and secrets where there is no appropriate default. A worker reads only its own role credentials; defer migration/serving credentials until those connections are constructed.

## Extend types without a reader

Use one focused `Type+ConfigReader.swift` in the executable for each configuration type that lacks native support. Read relative keys; the caller selects the scope:

```swift
import Configuration
import NIOCertificateReloading

extension TimedCertificateReloader.Configuration {
    init(config: ConfigReader) throws {
        self.init(
            refreshInterval: config.int(forKey: "refreshIntervalSeconds", as: Duration.self, default: .seconds(60)),
            certificateSource: .init(location: .file(path: try config.requiredString(forKey: "certificatePath")), format: .pem),
            privateKeySource: .init(location: .file(path: try config.requiredString(forKey: "privateKeyPath")), format: .pem)
        )
    }
}
```

`requiredString` sees both explicit values and application defaults. It does not require every path to be repeated in the deployment environment. The same initializer works with `config.scoped(to: "tls")` and `config.scoped(to: "temporal.tls")` without switches or fallback between them.

Accept only the reader for configuration values. A logger is acceptable when the object's construction actually requires one; the certificate configuration initializer does not. Set reload callbacks and the logger in the composition root. Runtime dependencies are different: `mTLS(config:certificateReloader:)` legitimately takes the existing reloader.

Policy readers can be executable-local extensions too. Keep Core's policy types independent of Swift Configuration. Derive policy defaults from Core's `.standard` values in the application provider rather than repeating literals in adapters. Use throwing reads for security settings so an absent override gets the standard value but a malformed supplied value fails. Read related settings from a snapshot when consistency matters; constructing a value once does not make it dynamically reconfigure when a provider changes.

## Names, units, and validation

Use hierarchy for concerns and camelCase relative keys. `tls.refreshIntervalSeconds` becomes `TLS_REFRESH_INTERVAL_SECONDS`; `temporal.tls.refreshIntervalSeconds` becomes `TEMPORAL_TLS_REFRESH_INTERVAL_SECONDS` under the environment provider's encoder.

For application-owned numeric durations, include the unit: `refreshIntervalSeconds`, `maxConnectionAgeSeconds`, `connectionGraceTimeSeconds`, or `expirationSeconds`. An interval describes repetition; expiration describes lifetime. Neither word specifies a unit. Read `Duration` with `config.int(forKey:as:default:)` where the receiving API uses it; convert at the adapter boundary for APIs that take `TimeInterval`. Keep unit suffixes off typed Swift properties. Library-owned keys retain their upstream units, including milliseconds.

Use required accessors for mandatory values and mark actual secret values `isSecret: true`. A file path is not the secret contents. Defaulted accessors can fall back on missing or invalid values; use throwing accessors or focused adapter validation where silent fallback would be wrong. Keep validation out of `Serve` and `Run`, and do not duplicate underlying library checks or add arbitrary positivity guards to a boilerplate cleanup.

Document the configuration contract in examples and deployment declarations, including required keys, defaults, scopes, and numeric units.

## Library adoption

A reusable library may expose a convenience initializer accepting `ConfigReader` that reads documented relative keys and delegates to its typed initializer; the application chooses providers, scopes, and deployment defaults. What a library may and may not do with configuration is the building-swift-server-libraries skill's ([API reference](../../building-swift-server-libraries/references/api.md#logging-configuration-and-lifecycle)).

When adopting a native reader, remove only the adapter logic it replaces. Keep endpoint construction and runtime dependencies where necessary. Do not create a new shared configuration package just to eliminate a few small executable-local extensions.

References: [Configuring applications](https://swiftpackageindex.com/apple/swift-configuration/1.2.1/documentation/configuration/configuring-applications), [Configuring libraries](https://swiftpackageindex.com/apple/swift-configuration/1.2.1/documentation/configuration/configuring-libraries).
