---
type: llm
focus: { source: file, path: deployment.md }
---

PASS if deployment.md places persistent Smallstep step-ca services in the existing Dokploy project with separate staging/production trust and state, keeps root signing keys offline and online intermediate signing material limited to the CA, and uses pinned versions or explicit reviewed-digest placeholders. Internal gRPC and CA traffic stay on intended private networks. Workloads see only their own leaf/key/trust directories, read-only where possible; renewers have write access only to their credential directories. Service and Temporal pairs have separate directories/scopes. Environment-scoped Dokploy variables are distinguished from per-application values and secret files.
FAIL if all workloads receive a shared directory of private keys, application containers receive CA signing keys, CA state is disposable on redeploy, one environment can obtain credentials trusted by the other by default, or a second Dokploy project is required without a concrete reason.
