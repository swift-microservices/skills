---
type: llm
focus: { source: file, path: acme-documents/Sources/DocumentsCore/Documents/UseCases/ListDocuments/ListDocumentsUseCase.swift }
---

PASS if the list use case takes subject: UserIdentity in its signature and decides in its own body whether the subject may list every document (an administrator check throwing its own .forbidden), with all I/O inside withTransaction.
FAIL if authorization is decided in a gRPC handler or interceptor, the identity type is UserPayload, or it receives a connection directly.
