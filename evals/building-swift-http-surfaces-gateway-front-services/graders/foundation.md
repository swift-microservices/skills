---
type: llm
focus: { source: file, path: acme-api/Package.swift }
---

PASS if all of these hold:
- Hummingbird is declared from 2.28.0 or newer with only the traits it uses: `traits: ["ConfigurationSupport"]` when its configuration integration is used, otherwise `traits: []`.
- swift-openapi-runtime, when declared, has `traits: []`.
- swift-configuration, when declared, has `traits: []`.

FAIL if any of those three packages is declared without a `traits:` argument (which keeps its full-Foundation defaults), lists default traits such as `FullFoundation` or `JSON`, or Hummingbird's floor is below 2.28.0. Judge semantics, not version-string formatting.
Grade only against these criteria; do not fail for issues they do not mention.
