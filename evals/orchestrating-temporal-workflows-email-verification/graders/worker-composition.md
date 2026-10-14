---
type: llm
focus: { source: file, path: acme-accounts/Sources/Accounts/Worker/Run.swift }
---

PASS if this file is the worker command's own composition root (a `Run` command, not part of serve): a PostgresDatabase built on a worker scope connecting as a dedicated worker role, a TemporalWorker registering the workflow and the Activity container, all owned by a ServiceGroup.
FAIL if the worker runs inside the gRPC serve process, connects as the service or owner role, starts a gRPC server, or reads the JWT verifying key.
