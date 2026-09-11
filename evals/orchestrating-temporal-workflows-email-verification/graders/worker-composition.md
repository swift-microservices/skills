---
type: llm
---

PASS if the process that runs the workflow is a `worker run` subcommand of the accounts executable with its own composition root, connecting to the accounts database as a dedicated worker role over a PostgresDatabase built on a worker scope, with a TemporalWorker registering the workflow and the Activity container, owned by a ServiceGroup, and the summary says it is deployed from the same image as the service.
FAIL if the worker is a separate executable product or image, runs inside the gRPC serve process, connects as the service or owner role, or reads the JWT verifying key.
