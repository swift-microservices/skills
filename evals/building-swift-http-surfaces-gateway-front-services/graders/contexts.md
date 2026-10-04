---
type: llm
focus: { source: file, path: acme-api/Sources/API/Contexts/AdminRequestContext.swift }
---

PASS if AdminRequestContext is built from IdentityRequestContext (the chain BasicRequestContext → IdentityRequestContext → AdminRequestContext), carries coreContext across the conversion, and admits only an identity with the administrator role.
FAIL if the conversion drops coreContext, admits a caller without the administrator role, or the identity type is not UserIdentity.
