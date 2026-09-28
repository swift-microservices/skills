---
type: llm
focus: { source: file, path: acme-backend/Package.swift }
---

PASS if the manifest declares Hummingbird with only the traits it needs (`traits: ["ConfigurationSupport"]` when its configuration integration is used, otherwise `traits: []`), declares swift-openapi-runtime with `traits: []` when present, and declares swift-configuration with `traits: []` when it is used for environment configuration. PostgresNIO remains: its full-Foundation linkage is an accepted upstream constraint.
FAIL if Hummingbird or OpenAPI runtime keeps its default FullFoundation trait, the configuration integration is dropped to reach `traits: []`, swift-configuration keeps its default JSON trait, or a required dependency is removed to avoid Foundation. Judge semantics, not version-string formatting.
