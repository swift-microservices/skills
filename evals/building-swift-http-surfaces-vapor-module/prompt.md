---
max_turns: 40
timeout_seconds: 900
allowed_tools: [Read, Glob, Grep, Write, Edit, Skill]
tags: [http, vapor]
---

Our organization "acme" runs a modular Swift monolith on Vapor 4 (package acme-backend, executable Acme). The notes module already has NotesCore with `CreateNoteUseCaseProtocol` (`callAsFunction(subject: UserIdentity, input: CreateNoteUseCaseInput) async throws(CreateNoteUseCaseError) -> Note`) and `ListNotesUseCaseProtocol` (`callAsFunction(subject: UserIdentity) async throws(ListNotesUseCaseError) -> [Note]`). Notes are tenant rows protected by row-level security on `app.caller_user_id`; `UserIdentity` comes from acme-core's AcmeAuthentication, and AcmePersistence provides the Vapor form of `UserSettingsMiddleware`.

Add the notes HTTP surface as focused excerpts under ./acme-backend: the controller in Sources/NotesHTTP/Controllers/NoteController.swift, its request/response conversions, the use-case error to problem mapping, and the route-group wiring in Sources/Acme/Serve/Serve.swift (only the routing part of the root). Signed-in users create and list their own notes; there are no anonymous note routes. Do not build or resolve packages, and do not scaffold unrelated modules.
