---
type: llm
focus: { source: file, path: acme-backend/Sources/Acme/Database/Migrations.swift }
---

PASS if the list adds `CreateServiceRole` first (one set of process roles for the monolith) and then every module's table and policy migrations, each added explicitly, in module dependency order.
FAIL if roles are created per module or after a table migration, a module's migrations are missing, or a module registers its migrations through a list of its own.
