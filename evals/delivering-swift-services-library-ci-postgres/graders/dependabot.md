---
type: regex
target: { source: file, path: .github/dependabot.yml }
pattern: '^(?=[\s\S]*github-actions)(?=[\s\S]*semver/none)(?=[\s\S]*groups:[\s\S]*patterns:\s*(?:\[\s*|-\s*)?["'']\*["''])(?![\s\S]*package-ecosystem:\s*["'']?swift)'
---
