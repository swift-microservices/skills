---
type: regex
target: { source: file, path: .github/dependabot.yml }
pattern: '^(?=[\s\S]*swift)(?=[\s\S]*github-actions)(?![\s\S]*develop)'
---
