---
type: llm
focus: { source: file, path: stack/compose.yaml }
---

PASS if no internal service publishes a host port: the Postgres instances, accounts, orders, the orders worker, the CA, the enrollment and renewal services, and the gateway have no `ports:` entry, and the gateway is reached only through the Tailscale sidecar (for example `network_mode: service:<sidecar>`) with internal services addressed by name on a private network.
FAIL if any of those services has a `ports:` mapping (a development convenience port included), or the gateway publishes its HTTP port.
