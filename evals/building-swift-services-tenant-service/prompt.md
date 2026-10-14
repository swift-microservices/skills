---
max_turns: 120
timeout_seconds: 1200
allowed_tools: [Read, Glob, Grep, Write, Edit, Skill]
tags: [building]
---

I'm starting a new Swift gRPC service called "documents" for our organization "acme". Each user owns their documents, and administrators can list every document. Scaffold the SwiftPM package: the targets, the manifest, a Document entity and its use cases, the gRPC service, the Postgres side including migrations and the policy that keeps users apart, and the serve command. Write the files into ./acme-documents and finish with a short summary of what you created. Name the executable target Documents with its composition root in Sources/Documents/Serve/Serve.swift; put the executable's complete migration list in Sources/Documents/Database/Migrations.swift, the row-level security policy in Sources/DocumentsPostgres/Migrations/Document/CreateDocumentsRLSPolicy.swift, the use cases for creating a document and listing the caller's own documents in Sources/DocumentsCore/Documents/UseCases/CreateDocument/CreateDocumentUseCase.swift and Sources/DocumentsCore/Documents/UseCases/ListOwnDocuments/ListOwnDocumentsUseCase.swift, and the gRPC conformance in Sources/DocumentsGRPC/Documents/DocumentService.swift. The contract is already released in acme-protos as Acme_Documents_V1_DocumentService: CreateDocument and ListOwnDocuments are the caller's own RPCs, and ListDocuments is the administrators' list of every document.

The service runs behind our HTTP gateway on a private service network; browsers and mobile clients do not dial this listener directly. Include its transport credential configuration and lifecycle.
