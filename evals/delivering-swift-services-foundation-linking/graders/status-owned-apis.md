---
type: llm
focus: { source: file, path: foundation-status.md }
---

PASS if the note says the application's own code uses, or should use, FoundationEssentials APIs for its needs, `JSONDecoder` and `Date.ISO8601FormatStyle` (or an equivalent `FormatStyle`/`ParseStrategy`), rather than `DateFormatter` or `ISO8601DateFormatter`. Saying the source was not audited is fine.
FAIL if it recommends `DateFormatter`, `ISO8601DateFormatter`, or enabling the OpenAPI client's FullFoundation trait because the process links Foundation anyway.
