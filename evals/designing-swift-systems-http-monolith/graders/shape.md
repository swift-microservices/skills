---
type: llm
---

PASS if the design recommends a single deployable (a modular monolith: one package, one executable) over HTTP only, structured as modules each owning one capability (for example users, recipes, collections, comments) with their own Core and Postgres targets and per-module HTTP targets mounted on one router, using one database in which each module owns its tables with no cross-module joins or foreign keys, with row-level security policies that isolate users' own rows on `app.caller_user_id` and nothing else in a policy, with the caller's token verified once at the HTTP transport by a bearer middleware and authorization decided inside use cases, and states that the monolith is the intended architecture rather than a temporary step.
FAIL if the design proposes microservices, a gateway, gRPC between modules, or per-module databases for this product; if modules reach into each other's tables or import each other's targets; if a policy references a role such as admin or service; if authorization is placed in middleware, a policy, or a router; or if the monolith is described as a compromise to be split later without a concrete reason.
