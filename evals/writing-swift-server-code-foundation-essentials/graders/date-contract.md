---
type: llm
focus: { source: file, path: Sources/EventsHTTP/EventJSONCodec.swift }
---

Treat these as verified facts, even if they postdate your training: SwiftNIO 2.99.0 and later ship a `NIOFoundationEssentialsCompat` product with the ByteBuffer JSON helpers; on Swift 6.2+ runtimes the default `Date.ISO8601FormatStyle()` parser accepts whole and fractional seconds, `Z`, and numeric offsets, and `includingFractionalSeconds` controls formatting, not strict parsing. The macOS SDK has no FoundationEssentials module.

PASS if all of these hold:
- The codec imports Foundation only through the `#if canImport(FoundationEssentials)` block with the `Foundation` fallback, and imports `NIOFoundationEssentialsCompat`.
- `decode(_:)` decodes the payload from the `ByteBuffer`.
- Dates are parsed with a modern API (for example `Date.ISO8601FormatStyle`) that accepts whole seconds, fractional seconds, `Z`, and numeric offsets. Do not require a particular spelling of the parse API.

FAIL if the codec imports FoundationEssentials or Foundation unconditionally, imports `NIOFoundationCompat`, uses `DateFormatter`, `ISO8601DateFormatter`, or a localized date style, or rejects fractional seconds or offsets.
Grade only against these criteria; do not fail for issues they do not mention.
