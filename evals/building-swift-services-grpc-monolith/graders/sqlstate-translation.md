---
type: llm
focus: { source: file, path: acme-backend/Sources/CatalogPostgres/Repositories/Item/PostgresItemRepository.swift }
---

PASS if the repository catches `PSQLError` with SQLSTATE `23505`, checks the constraint name, and throws its own repository error for the constraint it knows (such as a duplicate item name), rethrowing any other cause unchanged; and it throws an idempotency-conflict repository error when the idempotent insert returns no row.

FAIL if it maps every database error to one case, swallows an unknown error, matches on the error message text, or leaves `PSQLError` for Core to inspect.
