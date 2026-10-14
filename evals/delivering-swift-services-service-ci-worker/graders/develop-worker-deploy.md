---
type: regex
target: { source: file, path: .github/workflows/develop.yml }
pattern: '^(?=[\s\S]*secrets\.WORKER_APPLICATION_ID)(?=[\s\S]*worker:\s*true)'
---
