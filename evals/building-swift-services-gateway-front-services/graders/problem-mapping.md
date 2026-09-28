---
type: llm
focus: { source: file, path: acme-api/Sources/API/Middlewares/ErrorMiddleware/Problem/Conformances/RPCError+HTTPProblemResponse.swift }
---

PASS if RPCError is answered as an RFC 9457 problem detail whose HTTP status is mapped from the RPC code (for example notFound → 404, permissionDenied → 403, unauthenticated → 401, invalidArgument → 400, alreadyExists → 409, unavailable → 503), with a generic 500 only for the remaining codes.
FAIL if every upstream failure is mapped to 500, or client-classifiable codes such as notFound or permissionDenied collapse to 500.
