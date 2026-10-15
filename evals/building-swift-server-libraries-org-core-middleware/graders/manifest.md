---
type: regex
target: { source: file, path: Package.swift }
pattern: 'hummingbird(?:\.git)?\"(?:[^()]|\([^()]*\))*?traits:\s*\[\s*\]'
---
