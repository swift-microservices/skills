---
type: regex
target: { source: file, path: acme-backend/Package.swift }
pattern: 'swift-persistence-postgres[\s\S]*swift-authentication-hummingbird|swift-authentication-hummingbird[\s\S]*swift-persistence-postgres'
---
