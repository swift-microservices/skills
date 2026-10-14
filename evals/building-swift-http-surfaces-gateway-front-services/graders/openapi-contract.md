---
type: llm
focus: { source: file, path: acme-api/Sources/API/openapi.yaml }
---

PASS if all of these hold:
- Every operation has an `operationId` and a `security` entry: `[]` for sign-in, refresh, and the anonymous catalogue reads, and a bearer scheme for the profile operations.
- Every operation has a `default` response with `application/problem+json` content referring to a declared `Problem` schema (directly or through a shared response).
- `servers` declares a URL ending in the version path (for example `/v1`).

FAIL if the file is missing or empty, any operation lacks an `operationId`, a `security` entry, or the problem `default` response, or there is no `Problem` schema.
Grade only against these criteria; do not fail for issues they do not mention.
