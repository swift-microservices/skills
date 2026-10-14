---
type: regex
target: { source: file, path: .github/workflows/pull_request.yml }
pattern: 'static_sdk\.yml@main[ \t]*\n[ \t]+with:'
match: not_contains
---
