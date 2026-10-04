---
type: llm
focus: { source: file, path: design.md }
---

PASS if all of these hold:
- The design recommends one deployable modular monolith over HTTP, with modules that each own a capability and their own tables in one database.
- Users are kept apart by row-level security on the caller's id, while permissions are decided in use cases.
- The token is verified at the HTTP transport.

FAIL if the design proposes microservices, a gateway, gRPC between modules, or a database per module; lets modules join or reference each other's tables; puts an administrator or role check in a database policy; or calls the monolith a temporary step to be split without a concrete reason.
