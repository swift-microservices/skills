---
type: llm
---

PASS if the reply briefly and correctly explains each of the four features, distinguishes tools version (manifest API and minimum toolchain) from language mode (Swift 6 semantics and strict concurrency) and from default actor isolation (left nonisolated for a server), and does not describe `public import` as a re-export. It reports the build and test outcome truthfully, or the environment failure that prevented it.
FAIL if it claims a build or test passed without running it, or recommends MainActor default isolation for this server package.
