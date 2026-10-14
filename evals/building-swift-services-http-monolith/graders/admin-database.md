---
type: llm
focus: { source: file, path: acme-backend/Sources/Acme/Serve/Serve.swift }
---

PASS if Serve builds one `PostgresClient` per serving role (the tenant-scoped service role and the internal role) and no long-lived client as the owner; builds the create and the caller's own list use cases over a notebooks database on the service-role client (`PostgresNotebooksScope`); and builds the administrators' list of every notebook over a notebooks database on the internal-role client (`PostgresNotebooksInternalScope`).

FAIL if the administrators' list runs on the tenant-scoped database, one database serves both kinds of use case, or serving connects as the database owner.
