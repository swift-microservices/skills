---
type: llm
focus: { source: file, path: acme-backend/Sources/CatalogPostgres/Statements/Item/CreateItemStatement.swift }
---

PASS if all of these hold in the item insert:
- It inserts a caller-supplied idempotency key with the item and does not insert an `id` (the database generates it).
- Conflict on the idempotency key is handled atomically in the statement (`ON CONFLICT` on the key's unique constraint) with a `WHERE` that compares the stored item's fields to the new ones, so a retry with the same key and input returns the existing row and a mismatched retry returns no row.
- It returns the full row, including the generated id, with `RETURNING`.

FAIL if retries are detected by a separate SELECT before the insert, by an in-memory check, or by overwriting the stored item with the retry's values; or if the statement binds an id.
