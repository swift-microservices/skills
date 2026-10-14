---
type: llm
focus: { source: file, path: deployment.md }
---

PASS if the Temporal connections of billing and its worker use their own credential pair, renewer, and reloader, separate from the service-network pair; the self-hosted Temporal server's own certificate refresh is treated separately (verified against its implementation, renewed, or calendared); and mTLS is not treated as namespace authorization.
FAIL if Temporal reuses the service pair, the Swift reloader is assumed to refresh the Temporal server's certificates, or Temporal namespaces are treated as a TLS authorization boundary.
