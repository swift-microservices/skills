---
type: llm
---

PASS if the gateway's upstream connections use mTLS with its mounted client certificate and TLS private key, explicit CA trust, and full server hostname verification. It primes TimedCertificateReloader from NIOCertificateReloading before transport construction, supplies it through the transport factories, and owns it once in ServiceGroup. Judge Serve and its called configuration extensions together; trust configuration belongs in the factory. The gateway may share one suitable reloader across its service-network clients.
FAIL if any upstream uses plaintext or disables server verification, leaf credentials are loaded only once without a reload loop, the reloader is constructed but never run, or transports ignore the reloader. Public HTTP ingress termination by the platform does not remove the gateway's need for upstream mTLS.
