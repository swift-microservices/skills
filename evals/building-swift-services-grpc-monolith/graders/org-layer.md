---
type: llm
focus: { source: file, path: acme-backend/Package.swift }
---

PASS if the organization layer lives in this package as targets: `AcmeAuthentication` (the user identity) is declared with `.target(` and the module Core targets depend on it; `AcmePersistence` (the tenant-settings interceptor), where declared, is linked by the executable and not by any Core target; and `AcmeTesting`, where declared, is linked only by test targets.

FAIL if the manifest depends on an `acme-core` package (by URL or path) instead of declaring these targets, `AcmeAuthentication` is missing, or a non-test target links `AcmeTesting`.
