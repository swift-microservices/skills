---
type: llm
focus: { source: file, path: acme-backend/Sources/CatalogGRPC/Items/ItemService.swift }
---

PASS if the create-item handler starts with `requireAdministrator()`, passes the principal as `subject:`, and maps each typed use-case failure to its own status: forbidden to `.permissionDenied`, invalid input to `.invalidArgument`, a duplicate to `.alreadyExists`, an idempotency key reused with different input to `.failedPrecondition` (or another distinct non-internal code), and the unknown case to `.internalError`.

FAIL if the handler collapses distinct failures into one status, lets a use-case error escape unmapped, exposes a database error message, or calls the use case before requiring the administrator.
