---
type: llm
focus: { source: file, path: Sources/UtilityApp/main.swift }
---

PASS if main.swift imports UtilityExtensions itself (MemberImportVisibility needs it in the file that calls `utilityLabel`), spells the existential `any OperationRunner`, and still prints the same labelled value.
FAIL if the extension import exists only in another file, the existential is spelled without `any`, or the output behavior changes.
