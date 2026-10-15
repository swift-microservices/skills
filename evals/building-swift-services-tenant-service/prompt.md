---
runs: 1
max_turns: 40
timeout_seconds: 900
allowed_tools: [Read, Glob, Grep, Write, Edit, Skill]
tags: [building, rls]
---

I'm starting a new Swift gRPC service called "documents" for our organization "acme". Each user owns their documents, and administrators can list every document. The contract is already released in acme-protos as Acme_Documents_V1_DocumentService: CreateDocument and ListOwnDocuments are the caller's own RPCs, and ListDocuments is the administrators' list of every document.

Write only the database side and how serve connects to it, under ./acme-documents: the executable's complete migration list in Sources/Documents/Database/Migrations.swift, the row-level security policy that keeps users apart in Sources/DocumentsPostgres/Migrations/Document/CreateDocumentsRLSPolicy.swift, and an excerpt of Sources/Documents/Serve/Serve.swift showing only the database clients and databases it builds and which use cases each one serves. Don't scaffold the rest of the package, and don't build or resolve packages.
