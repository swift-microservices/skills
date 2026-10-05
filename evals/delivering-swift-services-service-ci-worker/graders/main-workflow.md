---
type: llm
focus: { source: file, path: .github/workflows/main.yml }
---

PASS if this workflow runs on `push` to `main` in a concurrency group for that branch that does not cancel in progress, runs the checks, then publishes through `./.github/workflows/image.yml` with publishing on, `needs` the checks and `packages: write` on that job only, then deploys production in a job that `needs` the publish job, with `PROD_DOKPLOY_URL`, `PROD_API_TOKEN`, and `PROD_APPLICATION_ID`. It deploys the worker application from the same image too, with `PROD_WORKER_APPLICATION_ID`, and the image workflow is called with the worker flag.
FAIL if deployment can start before publication, publication before the checks, or the workflow rebuilds the image outside the image workflow.
