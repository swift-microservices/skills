---
type: llm
focus: { source: file, path: acme-backend/Sources/AcmeHTTP/Middlewares/ProblemMiddleware.swift }
---

PASS if all of these hold:
- It is a Vapor `AsyncMiddleware` that catches every error from the responder chain and answers an RFC 9457 problem body (`type`, `title`, `status`, optional `detail` and `instance`) with content type `application/problem+json`.
- The status comes from the error's `AbortError` status (or the equivalent status the use-case error conformances declare), and anything unclassified becomes 500.
- A 5xx response is logged with its underlying error and does not expose that error to the client.

FAIL if the file is missing or empty, errors are answered as Vapor's default JSON `{"error": true, "reason": …}`, the content type is `application/json`, or a 5xx carries the internal error text in the body.
Grade only against these criteria; do not fail for issues they do not mention.
