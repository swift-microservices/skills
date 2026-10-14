---
type: llm
focus: { source: file, path: acme-backend/Sources/NotesHTTP/Controllers/NoteController.swift }
---

PASS if all of these hold:
- `NoteController` is a Vapor `RouteCollection` (or exposes tier-named registration methods over a `RoutesBuilder`) holding the two use-case protocols as `any` existentials, not databases or repositories.
- Each handler reads the verified caller with `req.auth.require(UserIdentity.self)` and passes it as `subject:`.
- Each use case runs inside `OperationContext.withContext(req.operationContext)`, so the tenant setting the settings middleware wrote reaches the transaction.

FAIL if a use case runs outside `OperationContext.withContext(req.operationContext)`, the controller reads a task-local principal (`OperationContext.current`) it assumes the middleware bound, or it holds a database or repository.
Grade only against these criteria; do not fail for issues they do not mention.
