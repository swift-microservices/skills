---
type: llm
focus: { source: file, path: acme-catalog/.github/workflows/develop.yml }
---

PASS if this workflow runs on `push` to `develop`, publishes the image only after the checks succeed, and deploys staging in a job or step that runs only after publication, as a single trigger bound to repository secrets with no condition on whether a secret is set.
FAIL if deployment can start before publication, the deploy is skipped when a secret is missing (for example `if: secrets.X != ''`), or a separate migration job runs although nothing records the project choosing a `migrate` one-shot.
