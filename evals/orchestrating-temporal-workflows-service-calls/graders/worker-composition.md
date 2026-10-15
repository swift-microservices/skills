---
type: regex
target: { source: file, path: acme-billing/Sources/Billing/Worker/Run.swift }
match: not_contains
pattern: 'GRPCServer|[Jj][Ww][Tt]'
---
