---
type: llm
focus: { source: file, path: swift-persistence-memory/AGENTS.md }
---

PASS if AGENTS.md has a Swift section stating Swift 6.3 with strict concurrency, swift-testing, documentation on every public declaration, and the formatter with its lint command (for example `swift-format lint --strict`).
FAIL if the file is missing, it names XCTest as the test framework, or it has no formatting or lint guidance.
Grade only against these criteria; do not fail for issues they do not mention.
