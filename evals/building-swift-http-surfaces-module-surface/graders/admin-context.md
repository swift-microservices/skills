---
type: llm
focus: { source: file, path: Sources/AcmeHTTP/Contexts/AdminRequestContext.swift }
---

PASS if all of these hold:
- `AdminRequestContext` is a child context of `IdentityRequestContext` and carries `coreContext` across rather than rebuilding it with `.init(source:)`.
- It holds a non-optional `UserIdentity`.
- Its initializer throws 401 (unauthorized) when no identity is bound and 403 (forbidden) when the role is not `.admin`, reading only the identity, with no database lookup.

FAIL if the file is missing, the conversion rebuilds `coreContext`, a non-administrator gets 401, or an anonymous caller is admitted.
Grade only against these criteria; do not fail for issues they do not mention.
