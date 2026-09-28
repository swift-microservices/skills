---
type: llm
focus: { source: file, path: foundation-status.md }
---

PASS if the note attributes the application's full-Foundation linkage to the resolved Vapor 4.122.2 and PostgresNIO 1.33.1, keeps both as required dependencies, lists the Foundation, FoundationInternationalization, and ICU shared libraries the image must ship, and says the application's own code uses FoundationEssentials with `Date.ISO8601FormatStyle`/`JSONDecoder` rather than `DateFormatter` or `ISO8601DateFormatter`. It says the executable's linkage is rechecked whenever dependencies change.
FAIL if it puts an Essentials-only linking gate on the application, which is guaranteed to fail, enables FullFoundation or a formatter class because the process links Foundation anyway, invents a trait that removes Foundation from Vapor or PostgresNIO, replaces the database or framework, or claims a static SDK build proves the absence of Foundation.
