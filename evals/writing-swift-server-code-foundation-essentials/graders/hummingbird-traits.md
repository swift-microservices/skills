---
type: regex
target: { source: file, path: Package.swift }
pattern: 'hummingbird-project/hummingbird(?:\.git)?"(?:[^()]|\([^()]*\))*?traits:\s*\[\s*(?:"ConfigurationSupport"|\.trait\(\s*name:\s*"ConfigurationSupport"\s*\))\s*,?\s*\]'
---
