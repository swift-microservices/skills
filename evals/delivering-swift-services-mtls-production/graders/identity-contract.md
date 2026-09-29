---
type: llm
---

PASS only if one HTTPS URI and assigned server DNS SANs are issued per process by an external CA, with independent production/staging roots and identity authorities. Workloads receive only their own keys and explicit roots, never issuer/provisioner/API credentials. Native required mTLS validates chains and key possession; clients verify server DNS names; internal operations authorize full caller identities. FAIL for shared keys, CA membership as permission, plaintext, hostname-verification bypass, or treating a URI parser as authentication. Host agents are not required for this mounted-file deployment.
