---
max_turns: 30
allowed_tools: [Read, Glob, Grep, Skill, Bash]
tags: [reviewing]
---

/swift-microservices:reviewing-swift-services .

Audit the supplied manifest, Core/use-case, scope, and row-level-policy excerpts for convention violations, read-only. This is an intentionally abridged fixture: transport, runnable composition, role/table migrations, repository implementation, use-case input/error/protocol definitions, tests, delivery, and the lockfile are omitted. Do not report their intentional absence as service defects or claim the fixture is a complete runnable service. The Acme dependency is fictional; report build limitations honestly. Check the declarations and dependencies actually supplied, distinguish those checks from runtime guarantees, and list what passes.
