---
type: llm
focus: { source: file, path: acme-documents/Sources/Documents/Database/Migrations.swift }
---

PASS if the list adds the documents table and then its row-level security policy, each explicitly, taking the internal role's name so the policy can grant that role every row.

FAIL if the policy migration is missing or comes before the table, or the documents migrations come from a list declared in `DocumentsPostgres`.
