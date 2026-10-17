---
type: regex
target: { source: file, path: .github/workflows/pull_request.yml }
pattern: 'uses:\s*[^\s.][^\s@]*@(?![0-9a-f]{40}\b)'
match: not_contains
---
