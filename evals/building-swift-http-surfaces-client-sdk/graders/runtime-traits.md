---
type: regex
target: { source: file, path: acme-sdk/Package.swift }
pattern: 'swift-openapi-runtime(?:\.git)?"(?:[^()]|\([^()]*\))*?traits:\s*\[\s*\]'
---
