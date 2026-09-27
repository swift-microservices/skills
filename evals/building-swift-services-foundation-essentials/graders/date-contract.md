---
type: llm
---

PASS if the actual codec imports FoundationEssentials (directly or with an SDK compatibility fallback) and decodes the specified ISO 8601 wire contract through modern date parsing. The implementation must handle whole seconds, fractional seconds, and equivalent numeric-offset timestamps; invalid string input must become DecodingError.dataCorrupted with the creationDate coding path. Tests must exercise those behaviors through EventJSONCodec rather than only testing an unused formatter or helper. Compare dates with an appropriate tolerance for fractional seconds.
FAIL if new or retained codec code relies on DateFormatter, ISO8601DateFormatter, NumberFormatter, String(format:), or the JSON .formatted(DateFormatter) strategy; if it introduces ICU/localized formatting without a localization requirement; if it assumes includingFractionalSeconds enforces strict input presence on Swift 6.3; if it silently returns a default date for invalid input; or if the invalid-date test merely catches any error without checking its kind and field coding path. Do not require a particular spelling of the modern parse API or a particular number of test functions.
