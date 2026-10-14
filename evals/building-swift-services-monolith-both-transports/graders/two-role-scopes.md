---
type: llm
focus: { source: file, path: acme-library/Sources/Acme/Serve/Serve.swift }
---

PASS if all of these hold in Serve:
- It builds two `PostgresClient`s, one for the tenant-scoped service role and one for the internal role, and no long-lived client for the owner.
- For the loans module it builds `PostgresDatabase<PostgresLoansScope>` over the service-role client and `PostgresDatabase<PostgresLoansInternalScope>` over the internal-role client; the members module has the same pair (`PostgresMembersScope`, `PostgresMembersInternalScope`).
- Borrowing and listing the caller's own loans are built over the tenant-scoped loans database, and the administrators' list of every loan over the internal loans database. The members lookup the adapter calls may run on either members database: the internal one, or the tenant-scoped one when it reads only the caller's own row.

FAIL if one database serves both the caller's own and the administrators' use cases of a module, the administrators' list runs on the tenant-scoped database, or serving connects as the database owner.
