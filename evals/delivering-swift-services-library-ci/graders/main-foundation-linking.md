---
type: regex
target: { source: file, path: .github/workflows/main.yml }
pattern: '^(?=[\s\S]*vapor/ci/\.github/workflows/check-foundation-linking\.yml@main)(?=[\s\S]*swift_image:\s*["'']?swift:6\.3-noble)(?=[\s\S]*swift_image:\s*["'']?swift:6\.4-noble)'
---
