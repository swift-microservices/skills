---
type: llm
focus: { source: file, path: acme-accounts/Sources/AccountsGRPC/Accounts/AccountInternalService.swift }
---

PASS if the internal handler converts the request to business input and calls an input-only use case (`callAsFunction(input:)` or similar), with no user subject, no process identity, and no read of `ServiceContext` to find a caller. A user or account id in the request is passed as business data.

FAIL if the handler requires a bound user, fabricates a caller, maps the client certificate to an application principal, or checks a per-service application role.
