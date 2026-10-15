---
type: regex
target: { source: file, path: acme-accounts/Sources/AccountsWorkflows/EmailVerification/EmailVerificationActivities.swift }
match: not_contains
pattern: 'UUID\(\)'
---
