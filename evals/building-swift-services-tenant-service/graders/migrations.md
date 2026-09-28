---
type: llm
focus: { source: file, path: acme-documents/Sources/DocumentsPostgres/Migrations/DocumentsMigrations.swift }
---

PASS if the ordered migrations list starts with CreateServiceRole, includes an internal role for administrator reads, and then creates the documents table and its row-level security policy.
FAIL if role creation comes after a table migration or the policy migration is missing.
