---
max_turns: 30
allowed_tools: [Read, Glob, Grep, Skill, Bash]
tags: [reviewing]
---

/swift-microservices:reviewing-swift-services .

Please review this notes service against our conventions and tell me what needs fixing before it ships.

Review the supplied excerpts. This fixture intentionally omits transport/composition implementation, role/table migrations and the migration list, repository implementation, use-case input/error/protocol definitions, tests, delivery, and the lockfile. Do not report those omissions as defects; audit the declarations, dependencies, and policy actually present. The Acme dependency is fictional, so do not claim a complete build or runtime security validation.
