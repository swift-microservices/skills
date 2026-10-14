---
type: llm
focus: { source: file, path: acme-library/Package.swift }
---

PASS if the organization layer lives in this package as targets: `AcmeAuthentication` (the user identity), `AcmePersistence` (the tenant-settings interceptor and middleware), and `AcmeTesting` (the test doubles) are declared with `.target(` in this manifest; the module Core targets depend on `AcmeAuthentication`; `AcmeTesting` is linked only by test targets.

FAIL if the manifest depends on an `acme-core` package (by URL or path) instead of declaring those targets, any of the three is missing, or a non-test target links `AcmeTesting`.
