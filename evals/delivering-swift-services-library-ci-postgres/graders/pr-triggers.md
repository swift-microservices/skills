---
type: regex
target: { source: file, path: .github/workflows/pull_request.yml }
pattern: '^(?=[\s\S]*pull_request)(?=[\s\S]*\bopened\b)(?=[\s\S]*\breopened\b)(?=[\s\S]*\bsynchronize\b)'
---
