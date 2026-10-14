---
type: llm
focus: { source: file, path: .github/workflows/main.yml }
---

PASS if this workflow runs on `push` to `main`, publishes through `./.github/workflows/image.yml` with publishing on in a job that `needs` the checks and alone holds `packages: write`, then deploys production in a job that `needs` the publish job, bound to `PROD_DOKPLOY_URL`, `PROD_API_TOKEN`, and `PROD_APPLICATION_ID` with no condition on whether a secret is set.
FAIL if deployment can start before publication, publication before the checks, the deploy is skipped when a secret is missing, or the workflow builds the image outside the image workflow.
