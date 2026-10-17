---
type: regex
target: { source: file, path: .github/workflows/main.yml }
pattern: '^(?=[\s\S]*build-image\.yml@[0-9a-f]{40}[\s\S]*publish:\s*true)(?=[\s\S]*deploy\.yml@[0-9a-f]{40})(?=[\s\S]*environment:\s*staging)(?=[\s\S]*stg-service-41[\s\S]{0,40}stg-worker-41)(?=[\s\S]*DOKPLOY_TOKEN:\s*\$\{\{\s*secrets\.DOKPLOY_TOKEN)'
---
