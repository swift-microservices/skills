---
type: llm
focus: { source: file, path: acme-documents/Sources/Documents/Serve/Serve.swift }
---

PASS if all of these hold in Serve:
- A `TimedCertificateReloader` is created (for example with `makeReloaderValidatingSources`) before the server transport.
- The `GRPCServer` transport uses mTLS transport security given that reloader (directly or through a factory such as `.mTLS(config:certificateReloader:)`).
- The reloader is in the `ServiceGroup`.
- `BearerAuthenticationInterceptor` and `UserSettingsInterceptor` are applied only to the user service's descriptor.

FAIL if the listener has a plaintext option, the reloader is never added to the `ServiceGroup`, or an interceptor derives an application identity from the client certificate. Trust configuration inside a factory defined in another file is expected.
