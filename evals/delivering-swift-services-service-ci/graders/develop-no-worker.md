---
type: regex
target: { source: file, path: .github/workflows/develop.yml }
pattern: 'WORKER_APPLICATION_ID|worker:\s*true'
match: not_contains
---
