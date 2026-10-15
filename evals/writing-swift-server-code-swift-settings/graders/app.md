---
type: regex
target: { source: file, path: Sources/UtilityApp/main.swift }
pattern: '^(?=[\s\S]*import\s+UtilityAdapter)(?=[\s\S]*import\s+UtilityCore)(?=[\s\S]*import\s+UtilityExtensions)[\s\S]*\bany\s+OperationRunner\b'
---
