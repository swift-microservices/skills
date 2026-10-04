---
max_turns: 40
timeout_seconds: 900
allowed_tools: [Read, Glob, Grep, Write, Edit, Skill]
tags: [libraries, semver]
---

Callers of this library keep misreading `nil` from `authenticate(_:)`: our transports already pass a request with no credential through without calling the authenticator, so "declined" has no use. Change the contract so an authenticator returns the identity or throws, and update everything in this repository that states, documents, or tests the old behavior.

Then tell me how to label the pull request and what the release and the packages that depend on this one need. The latest release is 0.2.0. Networking is unavailable, so don't build or resolve, and don't commit, tag, or push.
