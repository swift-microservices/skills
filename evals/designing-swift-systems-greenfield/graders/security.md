---
type: llm
focus: { source: file, path: design.md }
---

PASS if the design separates user authentication and authorization from transport admission: user operations verify JWTs and pass the verified user to the owning use case for permission decisions; any service-to-service or worker-to-service calls use mTLS with explicit private CA trust, and internal operations accept business input without an application process principal. For separate processes, the design keeps internal listeners private and recognizes that every peer admitted by their trust policy can reach their internal APIs. For a monolith with only in-process module calls, do not require certificates between modules or invent a CA service without a network use case.
FAIL if shared API keys or process bearer tokens authenticate internal calls, certificates are mapped into application subjects or per-service permission roles, internal operations are exposed through the public gateway, or user permission decisions exist only in a gateway, interceptor, or database policy.
