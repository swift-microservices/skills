---
type: llm
focus: { source: file, path: acme-backend/Sources/NotesHTTP/Controllers/NoteController.swift }
---

PASS if the handlers convert the request body through a throwing conversion (a `try` initializer or function; the conversion may be defined in another file) and let the use cases' typed errors propagate out of the handler unchanged, so the problem mapping declared elsewhere decides their status.
FAIL if the controller catches the typed errors into a generic 500, swallows them, maps `forbidden` to anything but 403, or decides authorization itself (comparing ids or roles) instead of leaving it to the use case.
Grade only against these criteria; do not fail for issues they do not mention.
