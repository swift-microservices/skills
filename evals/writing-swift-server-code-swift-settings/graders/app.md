---
type: llm
focus: { source: file, path: Sources/UtilityApp/main.swift }
---

PASS if main.swift imports every module whose members it uses (UtilityAdapter, UtilityCore, and UtilityExtensions for `utilityLabel`), spells the existential `any OperationRunner`, and prints `utility: 42` (for example by applying `utilityLabel` to the interpolated result).
FAIL if a member-providing import is missing from main.swift, the existential is spelled without `any`, or the printed text would differ from `utility: 42`.
