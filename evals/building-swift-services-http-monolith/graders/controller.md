---
type: llm
focus: { source: file, path: acme-backend/Sources/NotebooksHTTP/Controllers/NotebookController.swift }
---

PASS if all of these hold in the notebooks controller:
- It holds use-case protocol existentials (`any …UseCaseProtocol`), not databases or repositories.
- The caller's own create and list routes pass the identity from the request context as `subject:` and read no user id from the path, query, or body.
- The administrators' list of every notebook is its own route over its own use case, registered behind `group(context: AdminRequestContext.self)` (around that route or the administrative collection).

FAIL if one route serves both the caller's list and the administrators' list (for example by a query parameter or a role branch), the administrator route is reachable without `AdminRequestContext`, or the controller decides authorization itself instead of leaving it to the use case.
