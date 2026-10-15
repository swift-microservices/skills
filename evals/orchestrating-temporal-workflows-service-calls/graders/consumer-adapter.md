---
type: regex
target: { source: file, path: acme-billing/Sources/BillingGRPC/Clients/GRPCAccountClient.swift }
pattern: '^(?![\s\S]*(?:[Bb]earer|[Aa]uthorization))[\s\S]*AccountInternalService'
---
