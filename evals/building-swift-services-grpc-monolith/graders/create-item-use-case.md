---
type: llm
focus: { source: file, path: acme-backend/Sources/CatalogCore/Items/UseCases/CreateItem/CreateItemUseCase.swift }
---

PASS if the item-creation use case takes subject: UserIdentity, checks .admin in its own body before any I/O and throws its own .forbidden, and runs its repository call inside database.withTransaction.
FAIL if authorization for item creation is left to a handler or interceptor, it receives a connection directly, or it reads ServiceContext.
