---
type: regex
target: { source: file, path: .github/workflows/checks.yml }
pattern: 'continue-on-error|schedule:|\n[ \t]+services:[ \t]*\n|uses:\s*[^\s.][^\s@]*@(?![0-9a-f]{40}\b)'
match: not_contains
---
