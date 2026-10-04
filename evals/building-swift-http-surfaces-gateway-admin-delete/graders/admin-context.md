---
type: llm
focus: { source: file, path: acme-api/Sources/API/Contexts/AdminRequestContext.swift }
---

PASS if AdminRequestContext is a ChildRequestContext of IdentityRequestContext that carries coreContext across (not rebuilt with `.init(source:)`), holds a non-optional UserIdentity, and in its initializer throws 401 when no identity is bound and 403 when the identity is not an administrator.
FAIL if a non-administrator gets 401, an anonymous caller is admitted, the conversion rebuilds coreContext, or the check is missing.
