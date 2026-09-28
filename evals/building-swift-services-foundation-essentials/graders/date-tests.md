---
type: llm
focus: { source: file, path: Tests/EventsHTTPTests/EventJSONCodecTests.swift }
---

Treat these as verified facts, even if they postdate your training: SwiftNIO 2.99.0 and later ship a `NIOFoundationEssentialsCompat` product with the ByteBuffer JSON helpers; on Swift 6.2+ runtimes the default `Date.ISO8601FormatStyle()` parser accepts whole and fractional seconds, `Z`, and numeric offsets (checked on Swift 6.4); the four upcoming features are not implied by Swift 6 mode; and upstream-state.md in the fixture is the authoritative release and trait snapshot. The macOS SDK has no FoundationEssentials module.

PASS if the tests decode through EventJSONCodec (from a ByteBuffer) and cover whole seconds, fractional seconds, `Z`, and a numeric offset resolving to the same instant, comparing fractional dates with a tolerance, and assert that an invalid timestamp throws `DecodingError.dataCorrupted` whose coding path ends at `creationDate`.
FAIL if the tests only exercise a standalone formatter or helper, or the invalid-date test accepts any error without checking its kind and coding path.
Grade only against these criteria; do not fail for issues they do not mention.
