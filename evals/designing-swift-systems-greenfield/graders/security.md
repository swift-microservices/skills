---
type: llm
---

PASS if the design says internal service-to-service calls are mutually authenticated with the stack's own CA, that users are identified by a token and processes (such as a worker or the payments service calling another) by their certificate, and that authorization decisions live inside the owning service's use cases.
FAIL if a shared API key, a shared HMAC secret, or a "service" token role is proposed for service-to-service calls, or if authorization is placed in a gateway, an interceptor, or a database policy.
