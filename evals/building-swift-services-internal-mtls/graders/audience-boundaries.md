---
type: llm
---

PASS if the billing call uses a long-lived internal-service client without a bearer token or authentication interceptor; the receiving internal handler passes business input directly to its use case, with no process subject and no Core ServiceContext access. AccountService continues to verify user JWTs and passes the verified user explicitly to its user use cases. Any user/account identifier in the internal request is business data, not a caller assertion.
FAIL if internal work needs a fabricated user, process token, certificate-to-principal conversion, per-service application role, or an authenticated user context; or if removing bearer authentication from the internal service also removes it from the user service. Business invariants and transaction boundaries still apply to internal operations.
