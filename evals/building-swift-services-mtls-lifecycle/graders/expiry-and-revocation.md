---
type: llm
---

PASS only if the answer distinguishes new handshakes, new protected RPCs and in-flight streams: TLS checks chains and server DNS at handshake; the authenticator rechecks caller leaf validity on protected RPCs; existing streams are not automatically revalidated. Use finite connection age/grace and deadlines. Roots are fixed for a transport: overlap/removal recreates transports, and emergency revocation closes active streams/listeners/clients. Report loaded-file health separately from peer acceptance, and alert on renewal failure and approaching expiry. FAIL for claiming a file update immediately revokes sessions, automatic root reload, or readiness as proof of trust.
