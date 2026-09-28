---
type: llm
focus: { source: file, path: design.md }
---

PASS if the design's runtime dependency discussion names which chosen libraries link full Foundation (for example the Postgres driver), says the system's own code uses FoundationEssentials with `FormatStyle`/`ParseStrategy` rather than `DateFormatter` or the other formatter classes, and has the deployed binaries' Foundation linkage checked on Linux rather than assumed from framework choice. Accept any compatible library choice.
FAIL if it promises the application is free of Foundation or ICU because of the framework it uses, treats a static SDK build as proof of that, recommends `DateFormatter` or another formatter class, or assumes every library has the same Foundation trait.
