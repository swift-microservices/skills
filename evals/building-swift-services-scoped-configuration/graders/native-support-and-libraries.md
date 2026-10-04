---
type: llm
focus: { source: file, path: configuration-notes.md }
---

PASS if the notes say the executable owns provider construction, environment selection, and deployment mount defaults, while a library adopting `ConfigReader` accepts a scoped reader, documents its relative keys and tuning defaults, and delegates to its typed initializer; and that native readers (Hummingbird, Temporal, Valkey) remove the need for hand-written adapters except for what they do not cover, such as Valkey's endpoint and TLS.

FAIL if the notes have a library construct `EnvironmentVariablesProvider` or bootstrap logging, claim Valkey's native reader configures endpoint or TLS, or propose a new shared configuration package.
