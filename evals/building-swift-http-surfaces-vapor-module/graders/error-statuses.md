---
type: llm
focus: { source: file, path: acme-backend/Sources/NotesHTTP/Problem/CreateNoteUseCaseError+Problem.swift }
---

PASS if `CreateNoteUseCaseError` gets an HTTP status the error middleware reads (for example a Vapor `AbortError` conformance with a `status`), mapping `.invalidBody` to 400, `.forbidden` to 403, and `.unknown` to 500, and its client-facing reason discloses no internal cause.
FAIL if the file is missing or empty, any case maps to another status, or every case becomes 500.
Grade only against these criteria; do not fail for issues they do not mention.
