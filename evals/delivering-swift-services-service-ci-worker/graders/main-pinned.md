---
type: regex
target: { source: file, path: .github/workflows/main.yml }
pattern: 'uses:\s*[^\s.][^\s@]*@(?![0-9a-f]{40}\b)|branches:[^\n]*develop'
match: not_contains
---
