---
type: llm
focus: { source: file, path: acme-api/Sources/API/Controllers/ItemController.swift }
---

PASS if the delete route is registered at the same path as the item resource (DELETE /v1/items/:id, via addAuthenticatedRoutes) inside a group converted to AdminRequestContext — `group(context: AdminRequestContext.self)` or equivalent — and its handler calls the user-facing catalog client's (`client`, the Acme_Catalog_V1_ItemService stub) delete RPC with the path id.
FAIL if the route lives under an /admin path, the role check is written inside the handler body, the handler uses the public client, or the route is registered in the public tier.
