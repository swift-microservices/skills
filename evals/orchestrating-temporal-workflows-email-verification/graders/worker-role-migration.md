---
type: llm
focus: { source: file, path: acme-accounts/Sources/Accounts/Database/Migrations.swift }
---

PASS if the list keeps CreateServiceRole, CreateInternalRole, CreateRegistrationsTable, and CreateRegistrationsRLSPolicy in their original order and adds a worker-role migration (`CreateWorkerRole` or equivalent) after all four, taking the worker role's name and password from the configuration; a policy naming the worker role, if added, comes after it.

FAIL if the worker-role migration is inserted before any of the four applied migrations, an applied migration is reordered or removed, or no worker-role migration is added.
