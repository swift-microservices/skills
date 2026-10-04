---
type: llm
focus: { source: file, path: acme-backend/Sources/Acme/Serve/Serve.swift }
---

PASS if all of these hold in Serve:
- Configuration comes from a `ConfigReader` whose providers put environment variables before the application's in-memory defaults.
- Readers are scoped by concern (for example `postgres`, `jwt`, `http.server`) and passed to native readers such as `ApplicationConfiguration(reader:)` or focused `init(config:)` extensions.

FAIL if Serve hard-codes mount paths or hosts inline, validates configuration with its own guard statements, or passes a default-path or directory argument to an adapter alongside its reader. A `default:` value on an individual key read (such as a log level or port) is fine. Calling helper extensions defined in other files is expected.
