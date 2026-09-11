---
type: llm
---

PASS if the plan, in order: establishes a baseline of the monolith (builds, dependency inventory, tracing the slice), defines and releases a versioned proto contract in the shared proto package before any implementation, builds the newsletter producer as a standalone service that preserves the existing behavior and owns an unqualified `subscribers` table in its own database, adapts the monolith consumer by keeping its existing use-case protocols and replacing only the implementation with a long-lived gRPC client, wires deployment in dependency order, treats data migration as an explicit plan with measurement, backup, and reconciliation, and removes the old schema, tables, and migrations only after cutover verification.
FAIL if the plan drops or deletes the old tables or migrations before cutover, if the web layer is changed to depend on protobuf or gRPC types directly instead of its existing use-case protocol, if the new service keeps the `newsletter.` schema qualifier, or if two contexts are extracted together because their tables join.
