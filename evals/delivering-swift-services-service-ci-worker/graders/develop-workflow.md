---
type: llm
focus: { source: file, path: .github/workflows/develop.yml }
---

PASS if this workflow runs on `push` to `develop`, publishes through `./.github/workflows/image.yml` with publishing on in a job that `needs` the checks and alone holds `packages: write`, then deploys staging in a job that `needs` the publish job, bound to `DOKPLOY_URL`, `API_TOKEN`, and `APPLICATION_ID` with no condition on whether a secret is set. A second deploy step or job for the worker application uses the same image and runs after publication too.
FAIL if deployment can start before publication, publication before the checks, the deploy is skipped when a secret is missing, or the workflow builds the image outside the image workflow.
