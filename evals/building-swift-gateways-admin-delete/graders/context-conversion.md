---
type: llm
---

PASS if the delete route is registered at the same path as the item resource (DELETE /v1/items/:id) inside a group converted to AdminRequestContext — `group(context: AdminRequestContext.self)` or equivalent — so the administrator check runs in the context's initializer, refusing an anonymous caller with 401 and a non-administrator with 403, and the handler calls the user-facing catalog client's delete RPC and maps its RPCError to problem details.
FAIL if the route lives under an /admin path prefix, if the role check is written inside the handler body or inside a middleware with a path exception, if the check is skipped, or if the response for a non-administrator is 401 rather than 403.
