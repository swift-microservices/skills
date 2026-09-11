---
type: regex
target: { source: file, path: acme-documents/Package.swift }
pattern: 'swift-persistence-postgres[\s\S]*swift-authentication-grpc|swift-authentication-grpc[\s\S]*swift-persistence-postgres'
---
