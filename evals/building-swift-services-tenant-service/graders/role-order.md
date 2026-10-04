---
type: llm
focus: { source: file, path: acme-documents/Sources/Documents/Database/Migrations.swift }
---

PASS if the executable's list adds `CreateServiceRole` first, then an internal role (`CreateInternalRole`), and only then the documents module's migrations.

FAIL if any role migration comes after a table migration, or the internal role is missing.
