---
type: llm
focus: { source: file, path: design.md }
---

PASS if user operations verify the user's JWT (once at the transport in a monolith, at every receiving process across services) and pass the verified user to the owning use case, which decides permissions; and every internal connection between processes (service to service, to Temporal, a worker) uses mTLS from a certificate authority the stack issues. The edge proxy reaching a client-facing listener over server TLS without a client certificate is correct, and a monolith with only in-process module calls needs no certificates between modules. A provider webhook route that verifies the provider's signature and then runs its use case on the internal database role is not an internal operation exposed publicly. An optional route-level role gate is fine when the use case still decides.

FAIL if internal calls are authenticated with shared API keys or process bearer tokens, certificates are mapped to application users or permission roles, an internal-only RPC or administrative operation is reachable through the public HTTP surface without the user's token, or user permissions are decided only in a gateway, middleware, or database policy.
