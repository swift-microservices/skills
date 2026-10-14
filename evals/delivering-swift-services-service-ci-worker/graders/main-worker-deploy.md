---
type: regex
target: { source: file, path: .github/workflows/main.yml }
pattern: '^(?=[\s\S]*secrets\.PROD_WORKER_APPLICATION_ID)(?=[\s\S]*worker:\s*true)'
---
