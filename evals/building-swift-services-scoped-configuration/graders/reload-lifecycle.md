---
type: llm
---

PASS if the excerpts validate the initial pair by priming each TimedCertificateReloader before passing it to transport creation, retain full server verification and explicit CA trust, and list each used reloader directly once in its process's ServiceGroup alongside the clients/server/worker. Reloaders actually supply credentials to their corresponding transports.
FAIL if Temporal uses the service pair, a reloader is optional or unstarted, the same reloader is run twice, or the transport still uses static credential files instead of the reloader. The code may share a service reloader among clients and server using that pair.
