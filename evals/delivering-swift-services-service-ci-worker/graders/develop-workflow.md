---
type: llm
focus: { source: file, path: .github/workflows/develop.yml }
---

PASS if this workflow runs on `push` to `develop` in a concurrency group for that branch that does not cancel in progress, runs the checks, then publishes through `./.github/workflows/image.yml` with publishing on, `needs` the checks and `packages: write` on that job only, then deploys staging in a job that `needs` the publish job, with `DOKPLOY_URL`, `API_TOKEN`, and `APPLICATION_ID`. It deploys the worker application from the same image too, with `WORKER_APPLICATION_ID`, and the image workflow is called with the worker flag.
FAIL if deployment can start before publication, publication before the checks, or the workflow rebuilds the image outside the image workflow.
