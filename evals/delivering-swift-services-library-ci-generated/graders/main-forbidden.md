---
type: regex
target: { source: file, path: .github/workflows/main.yml }
pattern: 'static_sdk\.yml|soundness\.yml|schedule:|runs-on:[^\n]*macos|continue-on-error'
flags: i
match: not_contains
---
