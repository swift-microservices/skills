---
type: llm
focus: { source: file, path: acme-catalog/Tests/CatalogCoreTests/Mocks/ItemUseCaseMocks.swift }
---

PASS if all of these hold:
- The mock repository is an `actor` conforming to `ItemRepository`, holding its items in a dictionary keyed by id and an optional injected failure.
- It has a `calls` counter (or equivalently named) that every repository method increments.
- A mock scope struct conforms to both `CreateItemUseCaseScope` and `GetItemUseCaseScope`.

FAIL if the repository is a class or struct guarded by a lock, it stores items in an array, some method does not increment the counter, or there is no counter.
