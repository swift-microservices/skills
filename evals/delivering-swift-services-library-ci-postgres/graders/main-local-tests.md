---
type: regex
target: { source: file, path: .github/workflows/main.yml }
pattern: '^(?=[\s\S]*uses:\s*\./\.github/workflows/tests\.ya?ml)(?![\s\S]*enable_linux_static_sdk_build:\s*true)(?![\s\S]*check-foundation-linking)'
---
