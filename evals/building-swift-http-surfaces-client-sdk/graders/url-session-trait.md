---
type: llm
focus: { source: file, path: acme-sdk/Package.swift }
---

PASS if all of these hold:
- The package declares a trait for the URLSession transport and enables it by default (`.default(enabledTraits:)`).
- The `OpenAPIURLSession` product dependency is conditional on that trait (`condition: .when(traits: [...])`), so building with default traits disabled links no URLSession transport.
- The library target runs the `OpenAPIGenerator` plugin and depends on `OpenAPIRuntime` and the token-authentication product.
- The platforms include iOS beside macOS.

FAIL if `OpenAPIURLSession` is an unconditional dependency, no trait gates it, the trait is not enabled by default, or iOS is missing.
Grade only against these criteria; do not fail for issues they do not mention.
