---
type: llm
focus: { source: file, path: Package.swift }
---

PASS if the manifest raises its dependency floors to the supplied compatible release snapshot (Hummingbird 2.27.0, hummingbird-auth 2.5.0, swift-openapi-runtime 1.12.1, and NIO 2.103.0), explicitly selects Hummingbird's ConfigurationSupport without FullFoundation or defaults, opts OpenAPI runtime out of defaults, sets swift-configuration to `traits: []` while keeping its product on the executable, and replaces the NIOFoundationCompat product with NIOFoundationEssentialsCompat. Accept equivalent version-requirement syntax and formatting.
FAIL if Hummingbird uses traits: [] and loses the required configuration feature, unneeded default traits remain enabled on Hummingbird, OpenAPI runtime, or swift-configuration, only NIO's version changes while its old compatibility product remains, dependencies are downgraded, or a needed product is removed. Do not accept a fictional FullFoundation trait on swift-configuration.
