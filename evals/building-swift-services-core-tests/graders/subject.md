---
type: llm
focus: { source: file, path: acme-catalog/Tests/CatalogCoreTests/Mocks/ItemUseCaseMocks.swift }
---

PASS if the file has a factory taking an id and a role with defaults (such as `makeSubject(id: UUID = .user, role: UserRole = .user)`) that builds a `UserIdentity` whose issue and expiry dates come from a fixed reference date (such as `Date.reference` from Values.swift) rather than the current time.

FAIL if the subject's dates use `Date()` or `Date.now`, the role cannot be chosen per test, or no factory exists and tests build identities inline.
