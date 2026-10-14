---
type: llm
focus: { source: file, path: acme-billing/Sources/BillingGRPC/Clients/GRPCAccountClient.swift }
---

PASS if the adapter conforms to the Core port, calls accounts through the `AccountInternalService` client, and sends the subscription id, any affected user id as plain data, and the idempotency key in the request message, with no bearer token or authorization metadata.
FAIL if it attaches a bearer token or a minted process token, calls a user-facing `AccountService` descriptor, or lets generated message types escape into Core.
