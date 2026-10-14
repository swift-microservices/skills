---
type: llm
focus: { source: file, path: acme-documents/Sources/DocumentsGRPC/Documents/DocumentService.swift }
---

PASS if all of these hold in the documents conformance:
- The caller's own handlers (create, list) start with `requireUser()` and pass the principal as `subject:`, taking no user id from the request.
- The administrators' list handler starts with `requireAdministrator()` and calls its own use case, separate from the caller's list.
- Typed use-case failures map to distinct statuses (`.permissionDenied` for forbidden, `.invalidArgument` for invalid input, `.internalError` for unknown).

FAIL if a handler calls its use case before requiring the principal, one handler serves both the caller's list and the administrators' list, or errors are collapsed into one status.
