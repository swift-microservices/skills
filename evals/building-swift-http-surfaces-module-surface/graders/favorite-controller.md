---
type: llm
focus: { source: file, path: Sources/CatalogHTTP/Controllers/FavoriteController.swift }
---

PASS if `FavoriteController` registers its routes for the requiring tier (over `IdentityRequestContext`), reads the caller from the context (for example `context.requireIdentity()` or a `requireUser()` helper), passes it as `subject:` to the favourites use cases, and takes no user id from the path, query, or body.
FAIL if a route takes a user id, compares a path id with the identity, decides authorization itself, or sets the tenant setting in the handler.
Grade only against these criteria; do not fail for issues they do not mention.
