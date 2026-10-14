---
type: regex
target: { source: file, path: .github/workflows/checks.yml }
pattern: '^(?=[\s\S]*enable_macos_checks:\s*false)(?=[\s\S]*enable_ios_checks:\s*false)(?=[\s\S]*enable_windows_checks:\s*false)'
---
