---
type: llm
focus: { source: file, path: acme-documents/Sources/DocumentsPostgres/Migrations/DocumentsMigrations.swift }
---

PASS if the module's list creates the documents table and then its row-level security policy, taking the internal role's name so the policy can grant that role every row. Role migrations are not expected here.

FAIL if the policy migration is missing or comes before the table.
