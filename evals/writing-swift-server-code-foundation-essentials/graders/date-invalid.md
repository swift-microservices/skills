---
type: llm
focus: { source: file, path: Sources/EventsHTTP/EventJSONCodec.swift }
---

Treat these as verified facts, even if they postdate your training: SwiftNIO 2.99.0 and later ship a `NIOFoundationEssentialsCompat` product with the ByteBuffer JSON helpers; on Swift 6.2+ runtimes the default `Date.ISO8601FormatStyle()` parser accepts whole and fractional seconds, `Z`, and numeric offsets, and `includingFractionalSeconds` controls formatting, not strict parsing. The macOS SDK has no FoundationEssentials module.

PASS if an invalid timestamp string makes decoding throw `DecodingError.dataCorrupted` at the `creationDate` coding path (for example via `DecodingError.dataCorruptedError(in: container, debugDescription:)` inside a custom date decoding strategy).
FAIL if invalid input is replaced with a default date, swallowed, thrown as an unrelated error type, or validated by relying on `includingFractionalSeconds`.
Grade only against these criteria; do not fail for issues they do not mention.
