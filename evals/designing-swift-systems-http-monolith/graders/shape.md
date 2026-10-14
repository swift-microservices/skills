---
type: llm
focus: { source: file, path: design.md }
---

PASS if all of these hold:
- The design recommends one deployable modular monolith over HTTP, with modules that each own a capability and their own tables in one database.
- Rows private to a user, the account row included, are confined by row-level security on the caller's id (`app.caller_user_id`), while permissions are decided in use cases. A public row's own state may widen the read predicate (`status = 'published' OR author_id = …`), world-readable tables may omit a tenant policy when the design says so, and credential material looked up by a secret on anonymous paths (a refresh token by digest) may have none.
- The token is verified at the HTTP transport.

The internal database role's own `USING (true)` policy is the expected two-role pattern, not a role check. A section on how a module would later become a service (a contract, a gateway, gRPC) is not a proposal for today.

FAIL if the design proposes microservices, a gateway, gRPC between modules, or a database per module for today; lets modules join or reference each other's tables; puts an administrator or application-role check in a database policy; leaves the account table without a tenant policy; or calls the monolith a temporary step to be split without a concrete reason.
