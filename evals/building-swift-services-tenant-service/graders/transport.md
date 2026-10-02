---
type: llm
---

PASS if the private service listener requires mTLS with explicit CA roots, primes TimedCertificateReloader from NIOCertificateReloading before constructing the transport, supplies that reloader to the listener, and owns it once in ServiceGroup. Trust and certificate-verification configuration are implemented in a focused scoped-reader factory rather than inline in Serve. User JWT and tenant-setting interceptors still apply only to user descriptors.
FAIL if the listener has a plaintext fallback, client certificates are optional or unverified, leaf credentials are loaded only once with no managed reload loop, or a certificate-derived application identity/interceptor is added. Server-side noHostnameVerification is valid for verifying client certificates against the configured CA; do not confuse it with disabling certificate verification.
