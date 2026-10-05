---
type: llm
focus: { source: file, path: acme-backend/Sources/Acme/Database/Migrations.swift }
---

PASS if the list adds `CreateServiceRole` first, then `CreateInternalRole` (a tenant table exists), then each scaffolded module's table and policy migrations, each added explicitly, with one set of roles for the whole process.

FAIL if roles are created per module, a role migration in this new package comes after a table migration (appending is only for a role added later), a module that exists in the package has no migrations added, or a module registers its migrations through a list of its own.
