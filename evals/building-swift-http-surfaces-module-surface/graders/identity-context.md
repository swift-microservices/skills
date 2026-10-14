---
type: llm
focus: { source: file, path: Sources/AcmeHTTP/Contexts/IdentityRequestContext.swift }
---

PASS if `IdentityRequestContext` is a child context of `BasicRequestContext` that conforms to HummingbirdAuth's `AuthRequestContext` with an optional `UserIdentity` identity, and copies `coreContext` from the parent rather than rebuilding it with `.init(source:)`.
FAIL if the file is missing, the identity is not `UserIdentity`, or `coreContext` is rebuilt with `.init(source:)`.
Grade only against these criteria; do not fail for issues they do not mention.
