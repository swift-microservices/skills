---
max_turns: 30
timeout_seconds: 600
allowed_tools: [Read, Glob, Grep, Skill]
tags: [reviewing, temporal]
---

/swift-microservices:reviewing-swift-services .

We just added a reservation workflow to the catalog service; please review it before it ships. This is an abridged excerpt: repositories, migrations, the gRPC transport, configuration, the workflow tests, and delivery are intentionally omitted, and the Acme dependency is fictional, so do not build or resolve packages and do not report those omissions as defects. Report concrete findings with file-and-line evidence and list what passes.
