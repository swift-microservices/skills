---
type: llm
focus: { source: file, path: acme-backend/Package.swift }
---

PASS if the notebooks HTTP target `NotebooksHTTP` runs the `OpenAPIGenerator` plugin, and any shared HTTP target (such as `AcmeHTTP`) does not run it.

FAIL if only a shared HTTP target or the executable runs the generator, or no target runs it.
