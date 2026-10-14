# Release snapshot for the evaluation

These are supplied facts for a closed, offline scenario, not a permanently current dependency catalog. The newest compatible releases in this scenario, with what their tagged manifests declare:

| Package | Version | Products used here | Traits (default-enabled marked) |
| --- | --- | --- | --- |
| swift-configuration | 1.2.0 | `Configuration` | `JSON` (default); its other optional traits are off by default |
| Hummingbird | 2.28.0 | `Hummingbird` | `ConfigurationSupport` (default), `FullFoundation` (default) |
| hummingbird-auth | 2.5.0 | `HummingbirdAuth` | none |
| swift-openapi-runtime | 1.12.1 | `OpenAPIRuntime` | `FullFoundation` (default) |
| SwiftNIO | 2.103.0 | `NIOCore`, and for Foundation interop either `NIOFoundationCompat` or `NIOFoundationEssentialsCompat` (added in 2.99.0) | none |

Sources: [swift-configuration manifest](https://github.com/apple/swift-configuration/blob/1.2.0/Package.swift), [Hummingbird](https://github.com/hummingbird-project/hummingbird/blob/2.28.0/Package.swift), [hummingbird-auth](https://github.com/hummingbird-project/hummingbird-auth/blob/2.5.0/Package.swift), [OpenAPI runtime](https://github.com/apple/swift-openapi-runtime/blob/1.12.1/Package.swift), [SwiftNIO](https://github.com/apple/swift-nio/blob/2.103.0/Package.swift).

The service's supported toolchain and platform floors accept these releases, and no other dependency edge in this fixture enables any of their traits. The executable reads configuration only from environment variables. The event date contract permits optional fractional seconds.
