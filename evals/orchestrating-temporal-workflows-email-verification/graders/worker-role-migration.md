---
type: regex
target: { source: file, path: acme-accounts/Sources/Accounts/Database/Migrations.swift }
pattern: 'CreateServiceRole[\s\S]*CreateInternalRole[\s\S]*CreateRegistrationsTable[\s\S]*CreateRegistrationsRLSPolicy[\s\S]*CreateWorkerRole'
---
