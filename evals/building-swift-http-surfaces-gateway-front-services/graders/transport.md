---
type: llm
focus: { source: file, path: acme-api/Sources/Acme/Serve/Serve.swift }
---

PASS if all of these hold in Serve:
- A `TimedCertificateReloader` is created (for example with `makeReloaderValidatingSources`) before any upstream transport.
- Every upstream `GRPCClient` uses an mTLS transport security that is given that reloader (directly or through a factory such as `.mTLS(config:certificateReloader:)`).
- The reloader is in the `ServiceGroup`.

FAIL if any upstream uses plaintext, disables server verification, or the reloader is created but never added to the `ServiceGroup`. Trust configuration inside a factory defined in another file is expected.
