---
type: llm
focus: { source: file, path: acme-billing/Sources/BillingCore/Ports/AccountClient.swift }
---

PASS if the port is a protocol declared in Billing's Core in Billing's own types: its operation takes business values (such as an account or user id and the subscription change) and throws its own port error, and the file imports no generated protobuf module, `GRPCCore`, or Accounts target.

FAIL if the port names a generated message or `RPCError`, takes a user identity or token to impersonate the user, or is declared outside Billing's Core.
