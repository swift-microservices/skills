---
type: regex
target: { source: file, path: acme-backend/Package.swift }
pattern: 'grpc-swift|GRPCCore|NotebooksGRPC'
match: not_contains
---
