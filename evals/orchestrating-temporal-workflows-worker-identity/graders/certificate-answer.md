---
type: llm
---

PASS only if the Activity calls BillingInternalService as the production entitlements-worker using SPIFFE mTLS, and its client matches the exact configured billing ID through `clientTransportSecurity(expectedServer:)`. Billing binds a full-domain `ServiceIdentity` through `SPIFFEAuthenticationInterceptor` and permits fulfillment only for the exact allowed worker in the use case, denying the authenticated audit worker. The user ID is business data in durable input and the RPC request, not a credential. An equivalent helper around the published API is acceptable.

FAIL if the worker mints/forwards a bearer token, uses a service role/API key/credential exchange, impersonates the user, compares identity by path alone, or permits all authenticated workloads. Do not mistake a worker's separate database role or a managed Temporal endpoint's own credential requirements for a service-authentication token.
