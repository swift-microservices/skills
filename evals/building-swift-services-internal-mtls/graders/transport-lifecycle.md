---
type: llm
---

PASS if the internal listener requires client certificates against explicit CA roots, outgoing clients verify server chain and hostname, and both processes prime TimedCertificateReloader via makeReloaderValidatingSources before transport construction and run it once in ServiceGroup. The transport factories use the passed reloader and read relative trust keys; the reloader configuration adapter accepts a reader without a logger argument. dependencies.md names NIOCertificateReloading from swift-nio-extras and the gRPC lifecycle integration used. A process can share one reloader across transports using the same suitable credential pair.
FAIL if credentials are only loaded at startup, a constructed reloader is never run, the client disables hostname verification, the listener offers plaintext or unauthenticated TLS, or factories accept but ignore the reloader. Judge concrete code, not only the summary. Server-side noHostnameVerification still verifies the client chain and is acceptable.
