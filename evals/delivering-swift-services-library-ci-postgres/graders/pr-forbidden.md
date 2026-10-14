---
type: regex
target: { source: file, path: .github/workflows/pull_request.yml }
pattern: 'schedule:|runs-on:[^\n]*macos|continue-on-error|\|\|\s*true|--disable-automatic-resolution|--force-resolved-versions|diagnose-api-breaking'
flags: i
match: not_contains
---
