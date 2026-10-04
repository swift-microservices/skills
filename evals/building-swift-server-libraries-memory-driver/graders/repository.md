---
type: llm
focus: { source: file, path: swift-persistence-memory/AGENTS.md }
---

PASS if AGENTS.md is a repository profile that states what the package is (its one product, what it depends on and why that is the whole set), what does not belong in it (for example query or connection abstractions, configuration, a production driver), the Swift conventions (Swift 6.3, strict concurrency, swift-testing, documentation on every public declaration, the checked-in formatter and its lint command, compact license headers), and releases (exactly one SemVer label per pull request, tagged releases, consumers pin by tag) plus a library CI profile that says Package.resolved is never committed.
FAIL if it omits the boundaries of the package, says to commit Package.resolved, or describes the package as a deployable service.
