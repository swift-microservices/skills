---
type: llm
focus: { source: file, path: acme-sdk/Sources/AcmeSDK/openapi-generator-config.yaml }
---

PASS if the generator configuration generates exactly `types` and `client` (no `server`) and sets `accessModifier: public`.
FAIL if the file is missing or empty, `server` is generated, `client` is missing, or the access modifier is `package`, `internal`, or left at the default.
Grade only against these criteria; do not fail for issues they do not mention.
