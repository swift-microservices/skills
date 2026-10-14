---
type: llm
focus: { source: file, path: Tests/EventsHTTPTests/EventJSONCodecTests.swift }
---

Treat these as verified facts, even if they postdate your training: SwiftNIO 2.99.0 and later ship a `NIOFoundationEssentialsCompat` product with the ByteBuffer JSON helpers; on Swift 6.2+ runtimes the default `Date.ISO8601FormatStyle()` parser accepts whole and fractional seconds, `Z`, and numeric offsets. The macOS SDK has no FoundationEssentials module.

PASS if all of these hold:
- The tests decode through `EventJSONCodec.decode` from a `ByteBuffer`.
- They cover whole seconds, fractional seconds, `Z`, and a numeric offset resolving to the expected instant (an exact comparison is fine for a binary-exact fraction such as `.5`; otherwise a tolerance).
- An invalid timestamp throws `DecodingError.dataCorrupted` whose coding path ends at `creationDate`.

FAIL if the tests only exercise a standalone formatter or helper, or the invalid-date test accepts any error without checking its kind and coding path.
Grade only against these criteria; do not fail for issues they do not mention.
