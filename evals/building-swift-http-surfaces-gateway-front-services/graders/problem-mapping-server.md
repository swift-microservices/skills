---
type: llm
focus: { source: file, path: acme-api/Sources/API/Middlewares/ErrorMiddleware/Problem/Conformances/RPCError+HTTPProblemResponse.swift }
---

PASS if the `RPCError` status mapping sends `cancelled` → 499, `unimplemented` → 501, `unavailable` → 503, and `deadlineExceeded` → 504, and uses 500 only for the codes it does not otherwise classify (a `default` branch).

FAIL if any of those four codes is missing or maps to another status, or 500 is not the fallback.
Grade only against these criteria; do not fail for issues they do not mention.
