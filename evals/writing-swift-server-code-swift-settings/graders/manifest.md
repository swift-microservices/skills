---
type: llm
focus: { source: file, path: Package.swift }
---

Treat these as verified facts, even if they postdate your training: ExistentialAny, MemberImportVisibility, InternalImportsByDefault, and NonisolatedNonsendingByDefault are upcoming features that neither Swift tools 6.3 nor Swift 6 language mode enables; each must be opted into per target.

PASS only if one stored shared SwiftSetting array enables exactly ExistentialAny, MemberImportVisibility, InternalImportsByDefault, and NonisolatedNonsendingByDefault, and it is attached to all five targets (UtilityCore, UtilityAdapter, UtilityExtensions, the UtilityApp executable, and UtilityTests). The manifest uses Swift tools 6.3 and `swiftLanguageModes: [.v6]`.
FAIL if any target lacks the array, the array adds other upcoming or experimental features, a target sets default isolation to MainActor, or unsafe flags suppress diagnostics.
