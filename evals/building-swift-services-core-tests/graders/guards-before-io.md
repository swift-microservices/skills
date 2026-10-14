---
type: llm
focus: { source: file, path: acme-catalog/Tests/CatalogCoreTests/ItemUseCaseTests.swift }
---

PASS if the non-administrator refusal and the bad-name and bad-idempotency-key refusals each expect the use case's own typed error (`.forbidden`, `.invalidName`, `.invalidIdempotencyKey`) and then assert the mock repository's call counter is 0, proving the refusal happened before any I/O.

FAIL if a refusal test only checks the error, only checks that no item was stored, or expects a generic error instead of the typed case.
