---
type: llm
---

PASS only if production uses provider attestation and short-lived coherent SVID/key/bundle generations; each workload has least-privilege access to its own key/provider endpoint, and no workload receives CA signing keys or secrets in environment contents/images. Trust bundles stay explicitly bound to domains; staging material is not merged into production trust. Incoming peers require full-chain verification and key possession; outgoing SPIFFE clients select exact upstream IDs. The unrelated managed HTTPS API keeps its provider's hostname/trust rules.

FAIL if URI SAN presence alone authenticates a workload, path equality admits staging, the provider's attestation is replaced by a caller-controlled identity string, production uses one-shot year-long leaves, or normal HTTPS hostname checks are disabled. Either protected provider sockets or coherent mounted-file generations are acceptable; do not prescribe a platform the prompt did not select.
