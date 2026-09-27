---
type: llm
---

PASS if the read-only report identifies missing settings on UtilityExtensions, UtilityApp, and UtilityTests, despite the populated shared array and explicit Swift 6 mode. It must explain that settings do not propagate to consumers; tools version, language mode, upcoming features, and default isolation are separate. Identify the UtilityCore import access problem in InlineRunner.swift and the @Sendable callback contract preventing caller-owned LocalState mutation. Note that migrating the app also requires any OperationRunner and a UtilityExtensions import in the using file, not just Imports.swift. Recommend matching plain callback contracts and retaining nonisolated server defaults, not blanket MainActor isolation or unsafe suppression. Include file-and-line evidence and passed checks. Do not invent an architecture defect from the intentional library/executable shape or claim an unperformed build passed. Any source/manifest edit is a failure.
