---
type: regex
target: { source: file, path: acme-catalog/.github/workflows/checks.yml }
pattern: 'swift\s+(test|build)[^\n]*(--disable-automatic-resolution|--force-resolved-versions)'
---
