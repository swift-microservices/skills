---
type: llm
focus: { source: file, path: stack/compose.yaml }
---

PASS if every image is pinned: third-party images (Postgres, Smallstep, Tailscale, any log or dashboard image) carry an explicit version tag or digest, and the acme images use a published tag supplied by a required variable or an explicit SHA tag.
FAIL if any image uses `latest`, has no tag, or a service has a `build:` section.
