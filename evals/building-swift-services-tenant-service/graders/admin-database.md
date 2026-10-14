---
type: llm
focus: { source: file, path: acme-documents/Sources/Documents/Serve/Serve.swift }
---

PASS if Serve builds one `PostgresClient` for the service role and one for the internal role, no long-lived client as the owner, a `PostgresDatabase<PostgresDocumentsScope>` over the service-role client for the create and the caller's own list, and a `PostgresDatabase<PostgresDocumentsInternalScope>` over the internal-role client for the administrators' list.

FAIL if the administrators' list runs on the tenant-scoped database, one database serves both kinds of use case, or serving connects as the database owner.
