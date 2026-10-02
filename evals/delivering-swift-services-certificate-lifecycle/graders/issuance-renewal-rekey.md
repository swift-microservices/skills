---
type: llm
focus: { source: file, path: deployment.md }
---

PASS if the plan enrolls and validates the initial pair before application startup, then keeps a renewer running using Smallstep step ca renew for leaf renewal and step ca rekey when a new private key is wanted. It accounts for private CA endpoint trust, required DNS SANs/TLS purposes, least-privilege enrollment credentials, file ownership, and renewal before expiry with monitoring. Rekey stages and validates the pair and coordinates publication, rather than claiming two separate file renames are pair-atomic. Commands may be representative but must distinguish enrollment, renewal, and rekey and leave secrets as placeholders.
FAIL if an application reloader is expected to issue certificates, renewal depends solely on a startup job, private keys are put in images/plain environment variables, renewers can arbitrarily enroll peers without restricted issuance policy, or the design requires application URI identities to authorize RPCs.
