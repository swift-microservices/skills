---
type: llm
focus: { source: file, path: acme-backend/Sources/CatalogCore/Items/UseCases/CreateItem/CreateItemUseCase.swift }
---

PASS if the use case takes a `Logger` as its last initializer parameter and logs the domain event: `info` after a successful create, `warning` on a known refusal (forbidden, duplicate, or idempotency conflict), and `error` in the catch-all that maps to `.unknown`, with the cause as `String(reflecting: error)` and identifiers as metadata.

FAIL if the catch-all maps to `.unknown` without logging the cause, a refusal is logged at `error`, the logger is created inside the use case, or a secret or full payload is logged.
