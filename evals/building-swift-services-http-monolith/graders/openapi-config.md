---
type: regex
target: { source: file, path: acme-backend/Sources/NotebooksHTTP/openapi-generator-config.yaml }
pattern: 'generate:[\s\S]*\btypes\b[\s\S]*accessModifier:\s*package|accessModifier:\s*package[\s\S]*generate:[\s\S]*\btypes\b'
---
