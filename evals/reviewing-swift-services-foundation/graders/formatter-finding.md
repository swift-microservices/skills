---
type: llm
focus: trace
---

Judge the review report (it may come back from a forked review agent as a tool result, then be relayed in the final reply).

PASS if the report lists as a finding, with file-and-line evidence, that Sources/Notes/JSON/NoteJSONCodec.swift decodes dates with `DateFormatter` and `.formatted`, and recommends `Date.ISO8601FormatStyle` (or an equivalent `FormatStyle`/`ParseStrategy` decoding) that keeps the wire contract, fractional seconds and numeric offsets included, and throws a `DecodingError` on invalid input.
FAIL if the formatter finding is missing, has no file reference, or recommends `ISO8601DateFormatter` or another formatter class.
