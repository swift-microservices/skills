---
type: regex
target: { source: file, path: acme-billing/Sources/BillingCore/Ports/AccountClient.swift }
pattern: '^(?![\s\S]*(?:import\s+(?:GRPC\w*|\w*Proto\w*|Accounts\w*)|RPCError|UserIdentity))[\s\S]*protocol\s+AccountClient\b'
---
