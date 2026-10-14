---
type: llm
focus: { source: file, path: acme-backend/Sources/NotebooksHTTP/Problems/CreateNotebookUseCaseError+HTTPProblemResponse.swift }
---

PASS if the create use case's typed error conforms to the shared problem-response protocol (such as `HTTPProblemResponse`) with a status per case that matches its meaning: invalid input (including an idempotency key reused with different input) 400, `.forbidden` 403 and a duplicate 409 where such cases exist, and `.unknown` 500, each with a stable title.

FAIL if every case maps to one status, `.unknown` maps to anything but 500, a database or repository error type appears, or the file builds its own response body instead of conforming the error.
