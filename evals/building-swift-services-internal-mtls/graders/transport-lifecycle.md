---
type: llm
focus: { source: file, path: acme-accounts/Sources/Accounts/Serve/Serve.swift }
---

PASS if all of these hold in the accounts root:
- A `TimedCertificateReloader` is created (for example with `makeReloaderValidatingSources`) before the server transport.
- The `GRPCServer` transport uses mTLS given that reloader, so client certificates are required against explicit trust roots.
- The reloader is in the `ServiceGroup`.
- The bearer interceptor is applied to the user-facing `AccountService` descriptor and not to `AccountsInternalService`.

FAIL if the listener offers plaintext or optional client certificates, the reloader is never run, or the internal service gets a bearer interceptor. Server-side `.noHostnameVerification` still verifies the client chain and is acceptable.
