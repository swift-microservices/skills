---
type: llm
focus: { source: file, path: AGENTS.md }
---

PASS if AGENTS.md records the repository profile: that it is a reusable library on the standard library CI (the workflows and what each runs), its MIT license and owner, the formatter and header conventions, and that `Package.resolved` is not tracked.
FAIL if AGENTS.md is missing, describes the package as a deployable service, or changes the license or owner.
