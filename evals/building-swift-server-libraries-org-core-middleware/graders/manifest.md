---
type: llm
focus: { source: file, path: Package.swift }
---

PASS if all of these hold:
- The hummingbird package is declared with `traits: []`.
- The `Hummingbird` product is in the AcmePersistence target's dependencies.
- `HummingbirdTesting`, if present, appears only in the test target.

FAIL if the AcmeAuthentication target depends on Hummingbird or GRPCCore, or a new product is added for the middleware.
