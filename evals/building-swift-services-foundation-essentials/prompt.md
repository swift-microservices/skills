---
max_turns: 25
allowed_tools: [Read, Glob, Grep, Write, Edit, Skill]
tags: [building, foundation]
---

Update this Swift 6.3 Hummingbird service's JSON event decoder. The API accepts ISO 8601 timestamps with whole or fractional seconds, including UTC and numeric offsets. Invalid timestamps must produce a DecodingError with the field's coding path. The existing Hummingbird configuration integration must keep working, and the ByteBuffer JSON helper is still needed.

Bring the relevant dependencies up to the newest compatible releases described in upstream-state.md and add tests for the wire contract. The supplied upstream state is the verified release snapshot for this evaluation; networking and dependency resolution are unavailable, so use that evidence and do not build or resolve packages. Modify the existing files rather than replacing the framework or removing the feature. Summarize the dependency and API choices and what still needs runtime verification.
