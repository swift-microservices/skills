---
type: llm
---

PASS only if the worker presents its own certificate and dials billing using native .mTLS(certificateReloader:), explicit environment CA roots, full hostname verification and a finite RPC deadline. The expected DNS name must match billing, not the local worker. No bearer propagation is needed. FAIL for noHostnameVerification, any-CA-peer acceptance without checking the target DNS name, custom URI-based TLS callbacks, or a missing direct product dependency. URI SANs identify incoming callers; DNS SANs authenticate the server endpoint.
