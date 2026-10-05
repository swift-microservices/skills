---
type: llm
focus: { source: file, path: acme-catalog/.env.example }
---

PASS if Catalog's `.env.example` documents the credential path overrides with scoped names (such as `TLS_CERTIFICATE_PATH` and `TEMPORAL_TLS_CERTIFICATE_PATH`) and every application duration setting with a unit suffix (such as `TLS_REFRESH_INTERVAL_SECONDS`, `GRPC_SERVER_MAX_CONNECTION_AGE_SECONDS`), with no secret values.

FAIL if a duration variable has no unit in its name, or any password or secret variable has a value, including a placeholder such as `change-me`; an empty value or `…` is correct.
