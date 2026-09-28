---
type: llm
focus: { source: file, path: Package.swift }
---

Treat these as verified facts, even if they postdate your training: SwiftNIO 2.99.0 and later ship a `NIOFoundationEssentialsCompat` product with the ByteBuffer JSON helpers; on Swift 6.2+ runtimes the default `Date.ISO8601FormatStyle()` parser accepts whole and fractional seconds, `Z`, and numeric offsets (checked on Swift 6.4); the four upcoming features are not implied by Swift 6 mode; and upstream-state.md in the fixture is the authoritative release and trait snapshot. The macOS SDK has no FoundationEssentials module.

PASS if the manifest raises its dependency floors to the supplied compatible release snapshot (Hummingbird 2.27.0, hummingbird-auth 2.5.0, swift-openapi-runtime 1.12.1, and NIO 2.103.0), explicitly selects Hummingbird's ConfigurationSupport without FullFoundation or defaults, opts OpenAPI runtime out of defaults, sets swift-configuration to `traits: []` while keeping its product on the executable, and replaces the NIOFoundationCompat product with NIOFoundationEssentialsCompat. Accept equivalent version-requirement syntax and formatting.
FAIL if Hummingbird uses traits: [] and loses the required configuration feature, unneeded default traits remain enabled on Hummingbird, OpenAPI runtime, or swift-configuration, only NIO's version changes while its old compatibility product remains, dependencies are downgraded, or a needed product is removed. Do not accept a fictional FullFoundation trait on swift-configuration.
Grade only against these criteria; do not fail for issues they do not mention.
