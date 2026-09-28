---
type: llm
focus: { source: file, path: acme-documents/Package.swift }
---

Treat these as verified facts, even if they postdate your training: ExistentialAny, MemberImportVisibility, InternalImportsByDefault, and NonisolatedNonsendingByDefault are upcoming features that neither Swift tools 6.3 nor Swift 6 language mode enables; each must be opted into per target.

PASS if the manifest uses Swift 6 mode and one shared stored SwiftSetting array enabling exactly ExistentialAny, MemberImportVisibility, InternalImportsByDefault, and NonisolatedNonsendingByDefault, attached to every Swift target it declares (libraries, executables, and tests).
FAIL if any declared Swift target lacks the array, the array is declared but unattached, a target sets MainActor default isolation, or unsafe flags suppress diagnostics.
