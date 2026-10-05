---
type: llm
focus: { source: file, path: acme-documents/Sources/DocumentsCore/Documents/UseCases/ListDocuments/ListDocumentsUseCase.swift }
---

PASS if all of these hold:
- The use case takes `subject: UserIdentity`, takes no user id as input, and does all I/O inside `withTransaction` on the tenant-scoped database, so the policy confines it to the caller's documents.
- Administrators listing every document is a separate RPC and use case, on the internal-role database with its own role check — not a branch in this one.

FAIL if this use case branches on the subject's role to serve administrators, takes a user id that it compares to the subject, the administrator decision is made in a gRPC handler or interceptor, or the use case receives a connection directly.
