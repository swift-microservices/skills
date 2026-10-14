---
type: regex
target: { source: file, path: .github/workflows/main.yml }
pattern: 'concurrency:[\s\S]*cancel-in-progress:\s*false'
---
