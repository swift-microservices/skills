---
type: llm
focus: { source: file, path: acme-sdk/Package.swift }
---

PASS if the manifest declares the `AcmeSDK` target with no `resources:` entry that copies or processes `openapi.yaml` or any path outside the target directory, so the generator plugin reads the document from the target's own directory.
FAIL if the manifest is missing, declares no `AcmeSDK` target, or any `resources:` entry references `openapi.yaml` or a path beginning with `..`.
Grade only against these criteria; do not fail for issues they do not mention.
