---
type: llm
---

PASS if the serving Temporal client and worker use their SDK's native Configuration(configReader:) integration with the SDK's own keys, and connect with a distinct temporal.tls certificate/key pair and explicit trust. Each process primes its Temporal TimedCertificateReloader from NIOCertificateReloading before transport creation and owns it in that process's lifecycle. Any service-listener credentials use a separate tls scope and reloader. Application mount defaults are provided by the executable, and shared configuration extensions take scoped readers without default-path parameters.
FAIL if Temporal reuses the service credential pair, the reloader is optional or absent from lifecycle, server hostname verification is disabled, API-key or plaintext alternatives are introduced, or a worker requires JWT keys. Do not require an unused service reloader in a worker that only contacts Temporal and its own database.
