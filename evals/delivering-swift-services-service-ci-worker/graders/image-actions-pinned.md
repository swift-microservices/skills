---
type: regex
target: { source: file, path: .github/workflows/image.yml }
pattern: 'uses:\s*[^\s.][^\s@]*@(?![0-9a-f]{40}\b)'
match: not_contains
---
