---
type: regex
target: { source: file, path: .github/dependabot.yml }
pattern: '^(?=[\s\S]*swift)(?=[\s\S]*github-actions)(?=(?:[\s\S]*?\bgroups:){2})(?=(?:[\s\S]*?patterns:\s*(?:\[\s*|-\s*)?["'']\*["'']){2})(?![\s\S]*multi-ecosystem)(?![\s\S]*develop)'
---
