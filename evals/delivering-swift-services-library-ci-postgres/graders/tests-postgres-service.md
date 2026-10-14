---
type: regex
target: { source: file, path: .github/workflows/tests.yml }
pattern: '^(?=[\s\S]*image:\s*["'']?postgres:18)(?=[\s\S]*pg_isready[^\n]*-h\s+127\.0\.0\.1)'
---
