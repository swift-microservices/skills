---
type: llm
focus: { source: file, path: acme-library/Sources/Acme/Database/Migrations.swift }
---

PASS if the list adds `CreateServiceRole` first, then `CreateInternalRole`, once each for the whole process, and then each module's table and policy migrations, each added explicitly with its own `migrations.add` call, a policy after its table and taking the internal role's name.

FAIL if roles are created per module or more than once, a role migration comes after a table migration, a module's table or policy migration is missing, the migrations are added through a loop or a list declared by a module, or a policy comes before its table.
