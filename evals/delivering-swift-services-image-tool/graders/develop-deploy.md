---
type: llm
focus: { source: file, path: acme-catalog/.github/workflows/develop.yml }
---

PASS if this workflow runs on `push` to `develop`, runs the checks, publishes the image through the image workflow only after the checks, and deploys to staging in a job that `needs` the publish job.
FAIL if deployment can start before publication or the image is built outside the image workflow.
