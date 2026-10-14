---
type: llm
focus: { source: file, path: acme-api/Sources/API/Middlewares/ErrorMiddleware/Problem/Conformances/RPCError+HTTPProblemResponse.swift }
---

PASS if `RPCError` is answered as an RFC 9457 problem whose HTTP status is chosen by its code, with every one of these client-side rows present:
- `invalidArgument`, `failedPrecondition`, and `outOfRange` → 400; `unauthenticated` → 401; `permissionDenied` → 403.
- `notFound` → 404; `alreadyExists` and `aborted` → 409; `resourceExhausted` → 429.

FAIL if any listed code is missing or maps to another status, or every upstream failure becomes 500.
Grade only against these criteria; do not fail for issues they do not mention.
