---
type: llm
---

PASS if the answer says the worker calls BillingInternalService, that billing identifies the worker by the mTLS client certificate it already presents on the connection (its SPIFFE URI name, bound by a certificate interceptor as a ServiceIdentity) with no token, no API key, and no shared secret, that the worker's gRPC client carries no interceptor, and that the user is carried as a user id field in the request and workflow input rather than as a forwarded token or a subject.
FAIL if the answer mints or forwards a token for the worker, introduces a service role or credential exchange, calls BillingService with a bearer token, or has the worker impersonate the user.
