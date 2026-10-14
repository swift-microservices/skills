---
type: llm
focus: { source: file, path: acme-accounts/Sources/AccountsPostgres/Scopes/PostgresAccountsWorkerScope.swift }
---

PASS if `PostgresAccountsWorkerScope` is a `PostgresScope` that conforms to the scope protocols of the use cases the worker's Activities run (such as `ExpireRegistrationUseCaseScope`) and builds its repositories from the connection.
FAIL if it conforms to the scope of a request-facing use case such as creating the registration, or opens another service's database.
