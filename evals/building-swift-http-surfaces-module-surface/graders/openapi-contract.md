---
type: llm
focus: { source: file, path: Sources/CatalogHTTP/openapi.yaml }
---

PASS if all of these hold:
- Every operation has an `operationId`.
- Every operation has a `security` entry matching who may call it: listing and reading items admit anonymous callers (`[]`, or an empty requirement `{}` offered beside the bearer scheme), and adding items and the favourites operations require the bearer scheme.
- Every operation has a `default` response with `application/problem+json` content referring to a declared `Problem` schema (directly or through a shared response).

FAIL if the file is missing or empty, any operation lacks one of these, or the item routes are split across a separate `/admin` path.
Grade only against these criteria; do not fail for issues they do not mention.
