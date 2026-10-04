---
max_turns: 25
timeout_seconds: 600
allowed_tools: [Read, Glob, Grep, Skill]
tags: [reviewing, http]
---

/swift-microservices:reviewing-swift-services .

Review the HTTP surface of this abridged monolith excerpt, read-only. The OpenAPI documents, persistence, use-case implementations, configuration, lifecycle, tests, and delivery are intentionally omitted, and the Acme dependency is fictional; do not report those omissions as defects, edit files, build, or resolve packages. Refresh tokens are database rows sent in the Authorization header, not signed JWTs. Report concrete findings with file-and-line evidence and list what passes.
