---
max_turns: 60
timeout_seconds: 1200
allowed_tools: [Read, Glob, Grep, Write, Edit, Skill]
tags: [libraries]
---

We want a new open-source package in the swift-microservices family: swift-persistence-memory, an in-memory driver for swift-persistence's `Database<Scope>` that consumers can use in integration tests without a server. A transaction runs the operation against a copy of a `Sendable` state value and commits that copy only if the operation returns; when the operation throws, the copy is discarded and the same error reaches the caller.

Create the complete package under ./swift-persistence-memory: the manifest, the driver in Sources/PersistenceMemory/MemoryDatabase.swift, its tests in Tests/PersistenceMemoryTests/MemoryDatabaseTests.swift, a README, an AGENTS.md, a DocC catalog, and the repository files a library in this family carries. It is MIT-licensed; the owner is Zaid Rahhawi.

Networking and dependency resolution are unavailable, so don't build or resolve. Finish with a short summary of the API, how the pull request should be labeled for its first release, and what you would still verify.
