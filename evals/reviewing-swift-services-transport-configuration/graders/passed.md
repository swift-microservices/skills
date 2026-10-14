---
type: llm
focus: trace
---

Judge the review report (it may come back from a forked review agent as a tool result, then be relayed in the final reply).

PASS if the report lists at least two correct elements under what passed (for example reloader priming, the reader-only reloader configuration, explicit CA trust with required client certificates on the server, native Temporal client configuration, or the reloader owned in the `ServiceGroup`), and claims no build, test, or handshake it did not run.
FAIL if it says server-side `.noHostnameVerification` disables client-certificate validation, objects to the client holding a TLS private key, or reports the intentionally omitted helper implementations as defects.
