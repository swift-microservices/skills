---
type: llm
focus: { source: file, path: Sources/AcmeHTTP/Middlewares/ErrorMiddleware/ErrorMiddleware.swift }
---

PASS if all of these hold:
- It is a Hummingbird `RouterMiddleware` that catches errors from `next` and answers RFC 9457 problem details with content type `application/problem+json`.
- An error conforming to the shared problem protocol answers with that error's own status; Hummingbird's `HTTPError` keeps its status; anything else becomes 500.
- Every 5xx is logged with its underlying error, and the 500 body does not carry the internal error text.

FAIL if the file is missing or empty, errors are answered as plain text or `application/json`, or every error becomes 500.
Grade only against these criteria; do not fail for issues they do not mention.
