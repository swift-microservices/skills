---
type: llm
---

PASS if the answer adds `notifications` and `notifications-worker` to the fixed process list of the one-shot certificate service so each gets its own leaf from the stack's own CA; each leaf carries a `spiffe://acme/notifications` (and `spiffe://acme/notifications-worker`) URI subject alternative name beside the DNS name the service is dialled by; each service mounts the shared certificate volume read-only with a `subpath` of its own directory at `/run/tls`; the service reads the material by path through `TLS_CERTIFICATE_PATH`, `TLS_PRIVATE_KEY_PATH`, and `TLS_TRUST_ROOTS_PATH` (or an anchor carrying them); both services depend on the certificate one-shot completing; and the answer states there is no plaintext mode or mode variable and that the certificate is the process's credential with no service token.
FAIL if certificates are passed as environment variable contents, if a plaintext or insecure mode is offered, if the worker is given a token or API key to authenticate, if the CA private key is mounted into the service, or if certificates are generated on the host outside the stack.
