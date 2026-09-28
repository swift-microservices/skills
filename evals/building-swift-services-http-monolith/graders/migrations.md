---
type: llm
focus: { source: file, path: acme-backend/Sources/Acme/Database/Migrations.swift }
---

PASS if the ordered migrations list starts with CreateServiceRole (one set of process roles for the whole monolith, not one per module), then an internal role when a tenant table exists, then each module's migration list in order.
FAIL if roles are created per module, if role creation comes after a table migration, or if a module's list is missing.
