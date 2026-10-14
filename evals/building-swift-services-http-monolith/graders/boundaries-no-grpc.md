---
type: regex
target: { source: file, path: acme-backend/Package.swift }
match: not_contains
pattern: 'grpc-swift|SwiftProtobuf|GRPCCore'
---
