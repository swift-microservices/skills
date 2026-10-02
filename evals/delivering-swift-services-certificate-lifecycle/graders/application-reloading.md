---
type: llm
focus: { source: file, path: deployment.md }
---

PASS if the plan names TimedCertificateReloader from NIOCertificateReloading, initial priming, transport integration, and one lifecycle-managed reloader per credential pair in each process. Service and Temporal reloaders are distinct. It explains that renewed leaves affect fresh handshakes, existing connections need bounded age/drain behavior, failed reloads retain the last usable pair and retry, and expiry still matters. Trust-bundle rotation uses overlap and coordinated transport restart/reconstruction; Temporal server credential reload is checked against its own implementation.
FAIL if trust roots are claimed to reload through the leaf reloader, renewal is claimed to re-authenticate live connections immediately, process restart is the only normal leaf-renewal mechanism, or Temporal namespaces are treated as TLS authorization boundaries.
