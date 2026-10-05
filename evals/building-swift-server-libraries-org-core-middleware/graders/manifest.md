---
type: llm
focus: { source: file, path: Package.swift }
---

PASS if all of these hold:
- The hummingbird package is declared with `traits: []`.
- The `Hummingbird` product is in the AcmePersistence target's dependencies.
- `HummingbirdTesting`, if present, appears only in the test target.

FAIL if the `.target(name: "AcmeAuthentication", …)` declaration's own `dependencies:` list includes Hummingbird or GRPCCore (other targets listing `"AcmeAuthentication"` as a dependency are expected), or a new library product is added for the middleware.
