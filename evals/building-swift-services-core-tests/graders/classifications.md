---
type: llm
focus: { source: file, path: acme-catalog/Tests/CatalogCoreTests/ItemUseCaseTests.swift }
---

PASS if all of these hold:
- The administrator test creates an item and asserts the returned item's values.
- The retried-create test makes the repository fail with `ItemRepositoryError.idempotencyConflict` and expects `CreateItemUseCaseError.idempotencyConflict`; the duplicate test does the same with `.duplicateName`.
- The missing-item test calls `GetItemUseCase` with an id the mock does not hold and expects `GetItemUseCaseError.itemNotFound`.

FAIL if the retry test only asserts that the mock returns the same item twice, an expected error is checked by message text, or the not-found case is missing.
