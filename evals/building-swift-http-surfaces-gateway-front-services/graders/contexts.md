---
type: llm
focus: { source: file, path: acme-api/Sources/API/Contexts/AdminRequestContext.swift }
---

PASS if all of these hold:
- `AdminRequestContext` is a child context of `IdentityRequestContext` and carries `coreContext` across the conversion rather than rebuilding it with `.init(source:)`.
- It holds a non-optional `UserIdentity`.
- Its initializer throws 401 (unauthorized) when no identity is bound and 403 (forbidden) when the identity is not an administrator.

FAIL if the conversion rebuilds or drops `coreContext`, admits a caller without the administrator role, answers a non-administrator with 401, or the check is missing.
Grade only against these criteria; do not fail for issues they do not mention.
