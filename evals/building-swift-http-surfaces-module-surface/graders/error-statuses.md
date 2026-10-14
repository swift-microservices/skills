---
type: llm
focus: { source: file, path: Sources/CatalogHTTP/Problems/CreateItemUseCaseError+Problem.swift }
---

PASS if `CreateItemUseCaseError` conforms to the shared problem-response protocol from AcmeHTTP (for example `HTTPProblemResponse`) with `.invalidName` → 400, `.forbidden` → 403, `.duplicateName` → 409, and `.unknown` → 500.
FAIL if the file is missing or empty, any case maps to another status, or the controller is expected to translate the error itself.
Grade only against these criteria; do not fail for issues they do not mention.
