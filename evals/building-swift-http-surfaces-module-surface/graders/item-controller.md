---
type: llm
focus: { source: file, path: Sources/CatalogHTTP/Controllers/ItemController.swift }
---

The router's path prefixes live in the composition root, not in this file; judge only the controller.

PASS if all of these hold:
- `ItemController` holds the item use-case protocols as `any` existentials and has registration methods named for the tier they mount into (for example `addPublicRoutes`, `addIdentifiedRoutes`, `addAuthenticatedRoutes`).
- Listing and reading are registered in a method for a tier that admits anonymous callers (public or identifying) and call their use cases with `input:` alone or no argument. Creating is registered on the group the method receives (no `admin` path segment added in the controller) inside `.group(context: AdminRequestContext.self)`, and passes the context's identity as `subject:`.
- The path id reaches the use case through a throwing conversion (`try`, with the conversion possibly in another file) or `parameters.require(_:as:)`, so a malformed id answers an error. A body conversion that cannot fail may be non-throwing.

FAIL if the role check is written inside a handler, the create route adds an `admin` path segment, a handler catches use-case errors into a generic 500, or a malformed id is silently replaced, defaulted, or dropped (for example `parameters.get` with a fallback).
Grade only against these criteria; do not fail for issues they do not mention.
