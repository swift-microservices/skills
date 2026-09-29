---
max_turns: 20
allowed_tools: [Read, Glob, Grep, Skill]
tags: [reviewing, mtls]
---

/swift-microservices:reviewing-swift-services .

Review the supplied workload mTLS identity, outgoing billing connection, fulfillment authorization,
readiness, and emergency-revocation code. Read REVIEW-SCOPE.md first for the intended behavior
and fixture boundary. Report actionable findings with file-and-line evidence, checks that pass,
and verification limitations. Stay read-only. This is not a runnable application; do not build
it or report intentionally omitted components as defects.
