---
type: regex
target: { source: file, path: acme-documents/Package.swift }
pattern: '\.package\(\s*url:\s*"[^"]*/swift-persistence-postgres(?:\.git)?"[\s\S]*\.package\(\s*url:\s*"[^"]*/swift-authentication-grpc(?:\.git)?"|\.package\(\s*url:\s*"[^"]*/swift-authentication-grpc(?:\.git)?"[\s\S]*\.package\(\s*url:\s*"[^"]*/swift-persistence-postgres(?:\.git)?"'
---
