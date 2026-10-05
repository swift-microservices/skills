---
type: llm
focus: { source: file, path: split.md }
---

PASS if all of these hold:
- It names the compliance boundary and the separate release cadence as the reasons for the split.
- Billing's contract is released in the shared proto package, with its service and, where another process calls in, its internal service, before consumers depend on it.
- Billing gets its own package, database, executable, and roles, keeping its Core and Postgres targets.
- Catalog keeps `CheckSubscriptionUseCaseProtocol`; only the implementation injected in acme-backend's composition root becomes a gRPC client adapter over mTLS.
- Billing never trusts a caller-asserted identity: either the user's original token is forwarded to Billing's service and verified by Billing, or the check is an internal mTLS operation that takes the user id as business data.
- Moving or deleting Billing's existing rows is left to the user's decision.

FAIL if Catalog depends on generated protobuf or gRPC types directly, a distributed transaction or cross-database query is proposed, or rows are moved or dropped without a decision.
