---
type: llm
---

PASS if the library receives Foundation linking workflows triggered on pull_request and push to main, using Vapor's check-foundation-linking.yml with a supported Swift 6.3 Linux image or a genuinely equivalent release-consumer/transitive-library inspection. The check permits FoundationEssentials and rejects full Foundation, FoundationInternationalization, and ICU. The explanation recognizes that the supplied library evidence supports its claim but static SDK success alone does not, and does not claim the newly written workflows have already run.
FAIL if Foundation linking is replaced by import-string greps or static SDK compilation alone, if the check builds only a test binary whose XCTest dependencies pollute the result, if FoundationEssentials itself is banned, if full Foundation/ICU is allowed silently, or if either required workflow trigger is missing.
