---
max_turns: 30
timeout_seconds: 900
allowed_tools: [Read, Glob, Grep, Write, Edit, Skill]
tags: [writing, foundation]
---

This Swift 6.3 Hummingbird service needs its dependencies and a JSON event decoder. In Package.swift, declare Hummingbird with its swift-configuration integration, hummingbird-auth, swift-configuration (configuration comes only from environment variables), swift-openapi-runtime, and SwiftNIO for the ByteBuffer JSON helpers, using the releases in upstream-state.md, and add their products to the targets that need them: EventsHTTP uses Hummingbird, HummingbirdAuth, OpenAPIRuntime, NIOCore, and the JSON helpers; Events uses Configuration.

Then write EventJSONCodec in Sources/EventsHTTP/EventJSONCodec.swift with `package static func decode(_ buffer: ByteBuffer) throws -> EventPayload`. The API sends ISO 8601 timestamps with whole or fractional seconds, in UTC or with numeric offsets; an invalid timestamp must produce a DecodingError with the field's coding path. Add tests for that wire contract in Tests/EventsHTTPTests/EventJSONCodecTests.swift.

upstream-state.md is the verified release snapshot for this evaluation; networking and dependency resolution are unavailable, so don't build or resolve packages. Summarize your dependency and API choices and what still needs runtime verification.
