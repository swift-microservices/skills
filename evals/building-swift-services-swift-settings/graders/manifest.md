---
type: llm
focus: { source: file, path: Package.swift }
---

PASS only if one stored shared SwiftSetting array enables exactly ExistentialAny, MemberImportVisibility, InternalImportsByDefault, and NonisolatedNonsendingByDefault, and it is attached to all five targets (UtilityCore, UtilityAdapter, UtilityExtensions, the UtilityApp executable, and UtilityTests). Swift tools 6.3 and `swiftLanguageModes: [.v6]` remain.
FAIL if any target lacks the array, the array adds other upcoming or experimental features, a target sets default isolation to MainActor, or unsafe flags suppress diagnostics.
