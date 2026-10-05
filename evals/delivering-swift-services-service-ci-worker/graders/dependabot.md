---
type: regex
target: { source: file, path: .github/dependabot.yml }
pattern: '(swift[\s\S]*target-branch:\s*develop[\s\S]*github-actions[\s\S]*target-branch:\s*develop)|(github-actions[\s\S]*target-branch:\s*develop[\s\S]*swift[\s\S]*target-branch:\s*develop)'
---
