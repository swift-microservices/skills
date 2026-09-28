---
type: llm
---

PASS if the Temporal code lives in an AccountsWorkflows target, the workflow-client protocol and the Activity service port are declared in AccountsCore without importing Temporal, the Workflow waits on a condition raced against a timeout of the registration's expiration and runs an expiration Activity before assigning an expired state, email delivery and verification-token issuance are separate Activities, an idempotency key or the registration id from workflow input drives retries rather than a UUID minted in the Workflow, the workflow ID is derived from the registration id with rejectDuplicate and useExisting policies, and the start happens after the registration transaction committed.
FAIL if the Workflow performs database or network work directly, if a UUID or Date() is generated in Workflow code, if a Temporal call is made inside withTransaction, or if Temporal types appear in AccountsCore.
