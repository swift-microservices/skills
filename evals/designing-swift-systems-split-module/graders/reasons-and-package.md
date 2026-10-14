---
type: llm
focus: { source: file, path: split.md }
---

PASS if the plan names the PCI compliance boundary and the separate team's release cadence as the reasons for the split, and gives Billing its own package, executable, database, and role migrations while keeping its Core and Postgres targets as they are.

FAIL if the plan rewrites Billing's Core, keeps Billing's tables in acme-backend's database for Billing's new service to read, or gives no reason for the split.
