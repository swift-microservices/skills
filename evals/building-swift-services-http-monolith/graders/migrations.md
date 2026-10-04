---
type: llm
focus: { source: file, path: acme-backend/Sources/Acme/Database/Migrations.swift }
---

PASS if the ordered list adds `CreateServiceRole` first, then `CreateInternalRole` (a tenant table exists), then each scaffolded module's own migration list (for example `NotebooksMigrations.migrations(internalRole:)`), with one set of roles for the whole process.

FAIL if roles are created per module, a role migration comes after a table migration, or a module that exists in the package has no list registered.
