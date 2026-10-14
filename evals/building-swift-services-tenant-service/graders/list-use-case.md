---
type: llm
focus: { source: file, path: acme-documents/Sources/DocumentsCore/Documents/UseCases/ListOwnDocuments/ListOwnDocumentsUseCase.swift }
---

PASS if all of these hold:
- The use case takes `subject: UserIdentity`, takes no user id as input, and does all I/O inside `withTransaction` on the tenant-scoped database, so the policy confines it to the caller's documents.
- It serves only the caller's own documents; if administrators listing every document is scaffolded, that is a separate use case on the internal-role database with its own role check, not a branch in this one.

FAIL if this use case branches on the subject's role to serve administrators, takes a user id that it compares to the subject, relies on a gRPC handler or interceptor for an administrator decision, or receives a connection directly.
