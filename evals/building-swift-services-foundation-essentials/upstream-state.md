# Release snapshot for the evaluation

These are supplied facts for a closed, offline scenario, not a permanently current dependency catalog. The newest compatible releases in this scenario are:

| Package | Version | Manifest evidence |
| --- | --- | --- |
| Hummingbird | 2.27.0 | Default traits: ConfigurationSupport and FullFoundation. ConfigurationSupport alone enables the configuration integration. Its NIO Foundation helpers use NIOFoundationEssentialsCompat. |
| hummingbird-auth | 2.5.0 | Does not require full Foundation; its Hummingbird dependency opts out of default traits. |
| swift-openapi-runtime | 1.12.1 | FullFoundation is default-enabled; there are no other traits needed by this service. |
| SwiftNIO | 2.103.0 | Provides NIOFoundationEssentialsCompat with the Data/ByteBuffer and Codable helpers used by the service. That product first appeared in 2.99.0. |

Sources: [Hummingbird](https://github.com/hummingbird-project/hummingbird/blob/2.27.0/Package.swift), [hummingbird-auth](https://github.com/hummingbird-project/hummingbird-auth/blob/2.5.0/Package.swift), [OpenAPI runtime](https://github.com/apple/swift-openapi-runtime/blob/1.12.1/Package.swift), [SwiftNIO](https://github.com/apple/swift-nio/blob/2.103.0/Package.swift).

The service's supported toolchain and platform floors accept these releases. No other dependency edge in this fixture enables their default traits. The Hummingbird configuration integration is a required feature, not an unused dependency. The event date contract permits optional fractional seconds; it does not require localized display formatting.
