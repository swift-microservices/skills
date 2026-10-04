---
max_turns: 40
timeout_seconds: 900
allowed_tools: [Read, Glob, Grep, Write, Edit, Skill]
tags: [libraries, organization-layer]
---

Our services are adding Hummingbird HTTP routes that reach the database directly, so acme-core needs the HTTP counterpart of `UserSettingsInterceptor`. Add it to this package with tests that run without a server, in Sources/AcmePersistence/UserSettingsMiddleware.swift and Tests/AcmeCoreTests/UserSettingsMiddlewareTests.swift, and update the manifest and the repository profile as needed. Networking is unavailable, so don't build or resolve. Finish by saying how the pull request should be labeled and how a service wires the middleware.
