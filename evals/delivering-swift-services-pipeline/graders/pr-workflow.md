---
type: llm
focus: { source: file, path: acme-catalog/.github/workflows/pull_request.yml }
---

PASS if this workflow runs on `pull_request`, runs the checks (directly or by calling the reusable checks workflow), and builds and validates the release image (directly or through the reusable image workflow) without publishing it.
FAIL if it pushes an image, grants `packages: write`, or deploys.
