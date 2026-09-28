---
type: llm
focus: { source: file, path: acme-documents/Package.swift }
---

PASS if any created or edited manifest uses Swift 6 mode and a shared stored SwiftSetting array enabling ExistentialAny, MemberImportVisibility, InternalImportsByDefault, and NonisolatedNonsendingByDefault on every owned Swift library, executable, and test target. Settings only on a library or an unattached array fail. No blanket MainActor default or unsafe suppression. Check imports at their actual API access and plain caller-isolated transaction callback contracts if those are changed. Do not demand a manifest edit for a task that did not create or edit one.
