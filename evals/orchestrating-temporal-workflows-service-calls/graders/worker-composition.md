---
type: llm
---

PASS if worker run remains a subcommand of the billing executable/image, owns a worker-role connection to billing's database, and constructs one long-lived accounts internal-service client without bearer interceptors. Activities receive consumer adapters/Core ports rather than making clients per invocation. The root runs the worker and its lifecycle dependencies in ServiceGroup and requires neither a gRPC listener, JWT keys, nor serving/migration database secrets.
FAIL if the worker uses an owner/service database role, runs inside Serve, exposes internal operations through the gateway, creates a new network client for each retry, or accesses another service's database.
