---
type: llm
focus: { source: file, path: acme-billing/Sources/BillingGRPC/Clients/GRPCAccountClient.swift }
---

PASS if the adapter conforms to Billing's port, wraps the generated `AccountInternalService` client over an injected long-lived `GRPCClient`, converts Billing's values to the request, and catches `RPCError` to map known status codes to the port's own errors, keeping an unavailable or deadline failure distinct from a business refusal.

FAIL if it creates a client per call, attaches a token or bearer interceptor, lets `RPCError` or generated types escape through the port, or maps every failure to a single error case.
