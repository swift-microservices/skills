---
type: llm
focus: { source: file, path: acme-documents/Sources/Documents/Serve/Serve.swift }
---

PASS if all of these hold in Serve:
- A `TimedCertificateReloader` is created (for example with `makeReloaderValidatingSources`) before the server transport.
- The `GRPCServer` transport uses mTLS transport security given that reloader (directly or through a factory such as `.mTLS(config:certificateReloader:)`).
- The reloader is in the `ServiceGroup`.
- `BearerAuthenticationInterceptor` is applied only to the self and admin services' descriptors, and `UserSettingsInterceptor` only to the self service's.

FAIL if the listener has a plaintext option, the reloader is never added to the `ServiceGroup`, or an interceptor derives an application identity from the client certificate. Trust configuration inside a factory defined in another file is expected.
