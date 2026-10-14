---
type: llm
focus: { source: file, path: acme-library/Sources/LoansPostgres/Scopes/PostgresLoansScope.swift }
---

PASS if `PostgresLoansScope` conforms to `PostgresScope` and to the use-case scope protocols of the caller's own operations (borrowing a book and listing the caller's own loans), and does not conform to the scope protocol of the administrators' list of every loan, so the compiler refuses building that use case over the tenant-scoped database.

FAIL if the scope adopts the administrators' list-all scope protocol, if the use cases share one scope protocol that both Postgres scopes adopt, or if the file is missing.
