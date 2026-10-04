---
type: llm
focus: { source: file, path: design.md }
---

PASS if user operations verify the user's JWT and pass the verified user to the owning use case, which decides permissions, and any connection between separate processes uses mTLS. A monolith with only in-process module calls needs no certificates between modules.

FAIL if internal calls are authenticated with shared API keys or process bearer tokens, certificates are mapped to application users or permission roles, internal operations are exposed through the public HTTP surface, or user permissions are decided only in a gateway, middleware, or database policy.
