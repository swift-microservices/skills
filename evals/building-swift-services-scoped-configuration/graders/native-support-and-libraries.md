---
type: llm
---

PASS if Temporal configuration uses the native reader and preserves the SDK's own scoping/keys; Valkey tuning uses its native reader with explicit endpoint/TLS construction for the documented gap. The explanation also recognizes Hummingbird's native reader without adding an unused HTTP server. For library adoption, it keeps provider construction, environment selection, and deployment mount defaults in the application; a library accepts a scoped reader, documents relative keys and tuning defaults, and delegates to its typed initializer.
FAIL if every library gets a hand-written duplicate adapter, native support is treated as configuring Valkey's endpoint/TLS when it does not, a library constructs EnvironmentVariablesProvider or bootstraps logging, or a new shared configuration framework is introduced for these small adapters. Do not require editing upstream libraries in this exercise.
