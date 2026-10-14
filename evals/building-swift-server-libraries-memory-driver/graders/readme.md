---
type: llm
focus: { source: file, path: swift-persistence-memory/README.md }
---

PASS if all of these hold:
- It says in a sentence what the package provides.
- It shows a use-case example built against `Database<Scope>` that matches the driver's API.
- It relates the package to swift-persistence and its other drivers (for example a family table).
- It lists requirements: Swift 6.3, and macOS 15 or Linux.

FAIL if the file is missing, the example does not match the driver's API, or requirements are missing.
Grade only against these criteria; do not fail for issues they do not mention.
