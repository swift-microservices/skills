---
type: llm
---

Judge the generated files and explanation together; API names alone are not evidence of correct wiring.

PASS only if the fulfillment RPC belongs to an internal service, the handler requires the bound service principal and reports missing authentication as unauthenticated, and the use case takes `service: ServiceIdentity`. The receiving composition shares one `SPIFFETransportSecurity` between its mTLS transport and required `SPIFFEAuthenticationInterceptor`. The mapped identity preserves the full validated SPIFFE ID, and the service principal uses `SPIFFEAuthenticator.Verification` as its credential. Equivalent helper functions and local variable names are acceptable.

FAIL if the implementation trusts request metadata, only extracts a URI from an unverified leaf, treats a missing certificate as an anonymous internal call, assigns the worker a bearer token/API key/shared secret/service role, or places the operation on a public/user service. Do not require a live issuer or generated proto implementation: those are outside this prompt.
