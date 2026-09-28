---
type: llm
focus: { source: file, path: Sources/EventsHTTP/EventJSONCodec.swift }
---

PASS if the codec imports FoundationEssentials (directly or with an SDK compatibility fallback) and NIOFoundationEssentialsCompat instead of NIOFoundationCompat, keeps decoding from a ByteBuffer, and decodes the ISO 8601 wire contract through modern date parsing (for example `Date.ISO8601FormatStyle`) that accepts whole seconds, fractional seconds, `Z`, and numeric offsets. Invalid string input must throw `DecodingError.dataCorrupted` at the `creationDate` coding path, for example via `dataCorruptedError(in: container, ...)`.
FAIL if the codec uses DateFormatter, ISO8601DateFormatter, NumberFormatter, String(format:), or the `.formatted(DateFormatter)` strategy; introduces localized/ICU formatting; relies on `includingFractionalSeconds` to enforce strict input on Swift 6.3; or silently substitutes a default date for invalid input. Do not require a particular spelling of the modern parse API.
