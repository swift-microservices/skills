---
type: regex
target: { source: file, path: .github/workflows/develop.yml }
pattern: 'concurrency:[\s\S]*cancel-in-progress:\s*false'
---
