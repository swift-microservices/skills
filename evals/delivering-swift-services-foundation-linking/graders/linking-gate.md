---
type: llm
focus: { source: file, path: acme-authentication/.github/workflows/foundation-linking.yml }
---

PASS if the workflow runs on pull_request and on push to main, and checks Foundation linking through Vapor's check-foundation-linking.yml reusable workflow at `@main` (the library profile's ref for Foundation consumer checks; a commit SHA is acceptable only with the deviation recorded) run for both `swift:6.3-noble` and `swift:6.4-noble`, or through an equivalent job that builds a release consumer of the library products and inspects its transitive shared libraries. The check permits libFoundationEssentials and rejects libFoundation, libFoundationInternationalization, and lib_FoundationICU.
FAIL if either trigger is missing, only one Swift version is checked, the check is an import grep or a static SDK build alone, it inspects a test binary whose XCTest dependencies pollute the result, it bans FoundationEssentials, or it silently allows full Foundation or ICU.
