---
type: llm
focus: { source: file, path: acme-api/Package.swift }
---

PASS if the manifest declares Hummingbird with only the traits it needs (`traits: ["ConfigurationSupport"]` when its configuration integration is used, otherwise `traits: []`), declares swift-openapi-runtime with `traits: []` when present, and declares swift-configuration with `traits: []` when it is used for environment configuration. If LoggingLoki is used, it depends on swift-log-loki 2.0.1 or newer, and the executable declares a NIO Foundation compatibility product only if it imports one directly.
FAIL if Hummingbird or OpenAPI runtime keeps its default FullFoundation trait, the configuration integration is dropped to reach `traits: []`, swift-configuration keeps its default JSON trait, or the executable declares NIOFoundationCompat. Judge semantics, not version-string formatting.
