---
type: llm
focus: { source: file, path: .github/workflows/pull_request.yml }
---

PASS if this workflow runs on `pull_request` types opened, reopened, and synchronize, cancels superseded runs per pull request, and calls `./.github/workflows/checks.yml` and `./.github/workflows/image.yml` without publishing, passing the worker flag to the image workflow.
FAIL if any job publishes an image, grants `packages: write`, or deploys.
