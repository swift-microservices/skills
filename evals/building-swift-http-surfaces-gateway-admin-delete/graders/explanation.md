---
type: llm
---

PASS if the reply says the administrator check happens when the request context is converted to `AdminRequestContext` (anonymous → 401, non-administrator → 403) from the verified token's role claim, without a database lookup, and that the catalog service still enforces its own authorization for the delete RPC on the forwarded token.
FAIL if it says the check is done inside the handler, that the gateway looks the user's role up in a database, or that the gateway's check replaces the service's own check.
Grade only against these criteria; do not fail for issues they do not mention.
