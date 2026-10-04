---
type: llm
focus: { source: file, path: acme-backend/Sources/NotesHTTP/Controllers/NoteController.swift }
---

PASS if NoteController is a Vapor `RouteCollection` holding the two use-case protocols (not databases or repositories), reads the verified caller with `req.auth.require(UserIdentity.self)`, and calls each use case inside `ServiceContext.withValue(req.serviceContext)` so the tenant setting the settings middleware wrote reaches the transaction; it converts requests and responses through throwing conversions, and maps the use cases' typed errors to problem details (a forbidden or not-found case to 403/404, unknown to 500 with the cause logged).
FAIL if a use case runs outside `ServiceContext.withValue(req.serviceContext)`, the controller reads a task-local principal it assumes the middleware bound, it holds a database or repository, or authorization is decided in the controller instead of the use case.
