---
type: llm
---

PASS only if readiness reflects `security.isReady`, provider retries/alerts are bounded by credential expiry, and expiry refuses new handshakes/protected RPCs without inventing grace beyond certificate validity. Root overlap allows A and B during rollout; after A is removed, subsequent protected RPCs revalidate even on established connections. Emergency `revoke()` is paired with explicit application shutdown/draining of active streams and outgoing transports. Configure finite connection age/grace and RPC deadlines appropriate to SVID lifetime.

FAIL if updates/revoke are claimed to instantly terminate active streams, an outage extends validity locally or disables verification, root removal is described as affecting only new connections, or a fixed indefinite retry hides expired readiness. Equivalent lifecycle wiring is acceptable; no exact timeout constant is required.
