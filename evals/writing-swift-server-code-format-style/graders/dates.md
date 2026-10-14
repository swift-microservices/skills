---
type: llm
focus: { source: file, path: Sources/BillingCore/InvoiceText.swift }
---

Treat these as verified facts, even if they postdate your training: `Date.ISO8601FormatStyle` and its parse strategy, including the `.year().month().day()` components with a UTC time zone, are implemented in FoundationEssentials; localized date format styles generally need FoundationInternationalization and ICU.

PASS if all of these hold:
- `timestamp(_:)` formats with `Date.ISO8601FormatStyle` (for example `date.formatted(.iso8601)`), producing `2026-10-14T09:30:00Z` for the test's instant.
- `dueDateText(_:)` and `dueDate(_:)` use an ISO 8601 format style and parse strategy limited to year, month, and day in UTC (for example `Date.ISO8601FormatStyle().year().month().day()` with `parse` or `Date(_:strategy:)`).
- `dueDate(_:)` returns nil, rather than throwing or defaulting, for unparseable text, and both signatures are unchanged.

FAIL if any of these three functions still uses `DateFormatter` or `ISO8601DateFormatter`, uses a localized date style, or would produce output different from the tests' expectations.
Grade only against these criteria; do not fail for issues they do not mention.
