---
type: llm
focus: { source: file, path: acme-authentication/.github/workflows/foundation-linking.yml }
---

PASS if the workflow runs on pull_request and on push to main, and checks Foundation linking through Vapor's check-foundation-linking.yml reusable workflow (pinned to a commit SHA or a ref) with a supported Swift 6.3 Linux image, or through an equivalent job that builds a release consumer of the library products and inspects its transitive shared libraries. The check permits libFoundationEssentials and rejects libFoundation, libFoundationInternationalization, and lib_FoundationICU.
FAIL if either trigger is missing, the check is an import grep or a static SDK build alone, it inspects a test binary whose XCTest dependencies pollute the result, it bans FoundationEssentials, or it silently allows full Foundation or ICU.
