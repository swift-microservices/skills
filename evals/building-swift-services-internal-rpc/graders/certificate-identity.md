---
type: llm
---

PASS if the RPC is placed on an internal gRPC service (named like PurchaseInternalService), the use case takes `service: ServiceIdentity` in its signature, the handler requires a bound `ServiceContext.current?.service` and answers `unauthenticated` when none is bound, the serve composition applies `CertificateAuthenticationInterceptor(authenticator: ServiceAuthenticator())` to that internal service, and the explanation says the worker is proved by the mTLS certificate it already presents, named by its SPIFFE URI, with no token and no service role.
FAIL if the worker is given a token, an API key, a shared secret, or a `service` role; if the RPC is put on the user-facing or public service; or if an allowlist of callers is placed in an interceptor rather than the use case.
