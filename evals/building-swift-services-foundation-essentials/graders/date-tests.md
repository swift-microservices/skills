---
type: llm
focus: { source: file, path: Tests/EventsHTTPTests/EventJSONCodecTests.swift }
---

PASS if the tests decode through EventJSONCodec (from a ByteBuffer) and cover whole seconds, fractional seconds, `Z`, and a numeric offset resolving to the same instant, comparing fractional dates with a tolerance, and assert that an invalid timestamp throws `DecodingError.dataCorrupted` whose coding path ends at `creationDate`.
FAIL if the tests only exercise a standalone formatter or helper, or the invalid-date test accepts any error without checking its kind and coding path.
