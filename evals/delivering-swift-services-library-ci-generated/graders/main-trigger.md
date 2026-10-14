---
type: regex
target: { source: file, path: .github/workflows/main.yml }
pattern: 'push:\s*\n\s*branches:\s*(\[\s*)?(-\s*)?["'']?main'
---
