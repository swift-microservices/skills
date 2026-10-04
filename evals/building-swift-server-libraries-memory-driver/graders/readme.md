---
type: llm
focus: { source: file, path: swift-persistence-memory/README.md }
---

PASS if the README says in a sentence what the package provides, shows install snippets for `.package(url: "https://github.com/swift-microservices/swift-persistence-memory.git", from: …)` and `.product(name: "PersistenceMemory", package: "swift-persistence-memory")`, shows a use-case example built against `Database<Scope>` that matches the API, relates it to swift-persistence and its other drivers, and lists requirements (Swift 6.3, macOS 15 or Linux).
FAIL if the install snippet uses a path or branch, the example does not match the driver's API, or requirements are missing.
