---
type: llm
focus: { source: file, path: Tests/CatalogHTTPTests/CatalogHTTPTests.swift }
---

PASS if the tests cover all of these:
- An anonymous request to a favourites route answers 401, and a request carrying a token the verifier rejects answers 401.
- A signed-in non-administrator creating an item answers 403, and an administrator reaches the create use case.
- A public item read succeeds without a token.
- At least one distinct use-case error mapping (for example a duplicate name → 409 or a missing item → 404) answers its status with `application/problem+json`.

FAIL if any of these is missing, or a test re-asserts a business rule through a mocked use case instead of checking routing, identification, conversion, or status.
Grade only against these criteria; do not fail for issues they do not mention.
