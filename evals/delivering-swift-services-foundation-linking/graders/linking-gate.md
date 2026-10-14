---
type: llm
focus: { source: file, path: acme-authentication/.github/workflows/foundation-linking.yml }
---

PASS if the workflow runs on `pull_request` and on `push` to `main`, and checks Foundation linking with Vapor's `check-foundation-linking.yml` reusable workflow at `@main` (a commit SHA is acceptable only with a comment recording the deviation) or with an equivalent job that builds a release consumer of the library products and inspects its shared libraries, permitting libFoundationEssentials and rejecting libFoundation, libFoundationInternationalization, and lib_FoundationICU.
FAIL if either trigger is missing, the check is an import grep or a static SDK build alone, it inspects a test binary whose XCTest dependencies pollute the result, it bans FoundationEssentials, or it allows full Foundation or ICU.
