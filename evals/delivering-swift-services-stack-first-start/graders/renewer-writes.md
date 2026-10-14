---
type: llm
focus: { source: file, path: stack/compose.yaml }
---

PASS if each process (api, accounts, orders, the orders worker) has its own credential directory, mounted read-only into the application (`:ro` or `read_only: true`) and read-write into a long-running renewer (restart policy such as `unless-stopped`) that runs `step ca renew` or an equivalent script; initial enrollment is a separate one-shot using a short-lived token; the CA's PKI is mounted read-only into the CA with its database on a separate volume.
FAIL if applications can write their credential directory, one volume holding every workload's keys is mounted into every application, renewal happens only at startup, or a service has no renewer.
