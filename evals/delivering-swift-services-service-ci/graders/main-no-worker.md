---
type: regex
target: { source: file, path: .github/workflows/main.yml }
pattern: 'WORKER_APPLICATION_ID|worker:\s*true'
match: not_contains
---
