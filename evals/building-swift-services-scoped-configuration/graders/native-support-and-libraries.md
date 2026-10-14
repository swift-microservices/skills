---
type: llm
focus: { source: file, path: configuration-notes.md }
---

PASS if the notes say the executable owns provider construction (environment before application defaults) and the deployment defaults such as mount paths, while a library adopting `ConfigReader` accepts a reader the caller has already scoped, documents its relative keys and tuning defaults, and delegates to its typed initializer.

FAIL if the notes have a library construct `EnvironmentVariablesProvider`, choose its own scope, hold deployment mount paths, or bootstrap logging.
