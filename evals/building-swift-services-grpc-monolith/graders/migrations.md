---
type: llm
focus: { source: file, path: acme-backend/Sources/Acme/Database/Migrations.swift }
---

PASS if the list adds the process's role migrations once and before any table migration: `CreateServiceRole` first, then `CreateInternalRole` when a module has tenant tables (such as tenant-scoped profile rows). After them come each module's table migrations, plus a policy migration only for a tenant table, each added explicitly with `migrations.add`. Catalogue items are not tenant rows, so Catalog correctly has no policy migration. Users and Catalog share no table, so either module's migrations may come first.
FAIL if a role migration appears after a table migration or more than once, a module's table migration is missing, a policy comes before its table, or a module contributes its migrations through a list or helper of its own.
