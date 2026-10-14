---
type: llm
focus: { source: file, path: split.md }
---

PASS if the plan moves Billing's contract out of acme-backend into a tagged shared proto package (`acme-protos`), with its user-facing service and, where another process calls in, an internal service, released before any consumer depends on it; and moves the in-package authentication, persistence, and testing targets into a tagged shared core package (`acme-core`) now that a second package needs them, with both packages pinned by tagged URL.

FAIL if the new service depends on acme-backend's targets, copies the shared targets into Billing, or pins a shared package with `.package(path:)`.
