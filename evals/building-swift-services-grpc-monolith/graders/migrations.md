---
type: llm
focus: { source: file, path: acme-backend/Sources/Acme/Database/Migrations.swift }
---

PASS if the ordered migrations list starts with CreateServiceRole (one set of process roles for the monolith) and then each module's migration list in order.
FAIL if roles are created per module or after a table migration, or a module's list is missing.
