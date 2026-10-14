---
type: regex
target: { source: file, path: acme-backend/Package.swift }
pattern: '\.package\(\s*url:\s*"[^"]*/swift-persistence-postgres(?:\.git)?"[\s\S]*\.package\(\s*url:\s*"[^"]*/swift-authentication-hummingbird(?:\.git)?"|\.package\(\s*url:\s*"[^"]*/swift-authentication-hummingbird(?:\.git)?"[\s\S]*\.package\(\s*url:\s*"[^"]*/swift-persistence-postgres(?:\.git)?"'
---
