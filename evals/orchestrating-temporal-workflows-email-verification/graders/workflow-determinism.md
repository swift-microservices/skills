---
type: regex
target: { source: file, path: acme-accounts/Sources/AccountsWorkflows/EmailVerification/EmailVerificationWorkflow.swift }
match: not_contains
pattern: 'Date\(\)|Date\.now|UUID\(\)|PostgresClient|GRPCClient'
---
