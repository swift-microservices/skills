---
max_turns: 120
timeout_seconds: 1800
allowed_tools: [Read, Glob, Grep, Write, Edit, Skill]
tags: [building, monolith, http]
---

We're a small team at "acme" starting a backend for a note-taking product. It's one deployable Swift server over plain HTTP on Hummingbird, no gRPC: users sign up and sign in, and each user owns their notebooks; administrators can list every notebook. Keep it modular so we could split it later, but ship one process with one Postgres database. Scaffold the SwiftPM package under ./acme-backend: the targets and manifest, the notebooks module with a create and a list use case, the Postgres side including migrations and the policy that keeps users apart, the HTTP routes, and the serve command. Name the executable target Acme and put its composition root in Sources/Acme/Serve/Serve.swift and its ordered migrations list in Sources/Acme/Database/Migrations.swift. Put the notebooks row-level security policy in Sources/NotebooksPostgres/Migrations/Notebook/CreateNotebooksRLSPolicy.swift and the use cases in Sources/NotebooksCore/Notebooks/UseCases/CreateNotebook/CreateNotebookUseCase.swift and Sources/NotebooksCore/Notebooks/UseCases/ListNotebooks/ListNotebooksUseCase.swift. Finish with a short summary.
