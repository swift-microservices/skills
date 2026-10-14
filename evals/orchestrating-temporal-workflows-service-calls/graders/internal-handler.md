---
type: llm
focus: { source: file, path: acme-accounts/Sources/AccountsGRPC/Accounts/AccountInternalService.swift }
---

PASS if the internal handler requires no user (no `requireUser()` or `requireAdministrator()`, since mTLS admits the caller), converts the request into business input, and calls an input-only use case.
FAIL if it reads a bearer token, derives a subject from the client certificate and passes it into Core, or writes to the database itself.
