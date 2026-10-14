---
type: llm
focus: { source: file, path: acme-api/Sources/API/Controllers/ItemController.swift }
---

PASS if all of these hold:
- The delete route is registered at the item resource's own path (`DELETE` on `:id` in the controller's `items` group, so `/v1/items/:id`), not under a separate `/admin` path or a verb-shaped path.
- It is registered from the identifying or requiring tier inside a group converted to `AdminRequestContext` (`group(context: AdminRequestContext.self)` or equivalent).
- Its handler calls the catalog client's delete RPC with the path id.

FAIL if the role check is written inside the handler body, the handler adds a resource or ownership check of its own, or the route is registered in the public tier.
Grade only against these criteria; do not fail for issues they do not mention.
