---
type: llm
focus: { source: file, path: Sources/EventsHTTP/EventJSONCodec.swift }
---

Treat these as verified facts, even if they postdate your training: SwiftNIO 2.99.0 and later ship a `NIOFoundationEssentialsCompat` product with the ByteBuffer JSON helpers; on Swift 6.2+ runtimes the default `Date.ISO8601FormatStyle()` parser accepts whole and fractional seconds, `Z`, and numeric offsets (checked on Swift 6.4); the four upcoming features are not implied by Swift 6 mode; and upstream-state.md in the fixture is the authoritative release and trait snapshot. The macOS SDK has no FoundationEssentials module.

PASS if the codec imports FoundationEssentials through the `#if canImport(FoundationEssentials)` / `Foundation` fallback (the package declares macOS, which has no FoundationEssentials module) and NIOFoundationEssentialsCompat instead of NIOFoundationCompat, keeps decoding from a ByteBuffer, and decodes the ISO 8601 wire contract through modern date parsing (for example `Date.ISO8601FormatStyle`) that accepts whole seconds, fractional seconds, `Z`, and numeric offsets. Invalid string input must throw `DecodingError.dataCorrupted` at the `creationDate` coding path, for example via `dataCorruptedError(in: container, ...)`.
FAIL if the codec imports FoundationEssentials unconditionally, uses DateFormatter, ISO8601DateFormatter, NumberFormatter, String(format:), or the `.formatted(DateFormatter)` strategy; introduces localized/ICU formatting; relies on `includingFractionalSeconds` to enforce strict input on Swift 6.3; or silently substitutes a default date for invalid input. Do not require a particular spelling of the modern parse API.
Grade only against these criteria; do not fail for issues they do not mention.
