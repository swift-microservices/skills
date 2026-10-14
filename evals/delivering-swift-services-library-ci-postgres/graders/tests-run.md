---
type: regex
target: { source: file, path: .github/workflows/tests.yml }
pattern: 'swift\s+test\s+--parallel[^\n]*matrix\.arguments'
---
