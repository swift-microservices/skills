---
type: regex
target: { source: file, path: acme-billing/Sources/Billing/Serve/Serve.swift }
pattern: '^(?![\s\S]*(?:[Bb]earer|noVerification|\.plaintext))(?=[\s\S]*TimedCertificateReloader)[\s\S]*GRPCClient'
---
