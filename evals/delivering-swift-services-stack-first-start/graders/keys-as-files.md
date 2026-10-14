---
type: llm
focus: { source: file, path: stack/compose.yaml }
---

PASS if the JWT private signing key reaches only accounts, as a mounted file (a Compose secret or read-only bind) with a path variable such as `JWT_PRIVATE_KEY_PATH`; the gateway and orders mount only the public key; the orders worker mounts no JWT key; TLS private keys and enrollment tokens are mounted files; no key, certificate, or token is the value of an environment variable.
FAIL if any service other than accounts receives the private key, a key or token is passed in `environment:`, or the CA's signing keys are mounted into an application.
