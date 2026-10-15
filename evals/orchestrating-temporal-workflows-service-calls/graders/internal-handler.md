---
type: regex
target: { source: file, path: acme-accounts/Sources/AccountsGRPC/Accounts/AccountInternalService.swift }
match: not_contains
pattern: 'requireUser|requireAdministrator|[Bb]earer'
---
