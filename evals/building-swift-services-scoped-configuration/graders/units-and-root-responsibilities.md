---
type: llm
---

PASS if application numeric duration keys carry Seconds (for example refreshIntervalSeconds, maxConnectionAgeSeconds, connectionGraceTimeSeconds), map consistently to scoped uppercase environment names, and convert to the receiving API's duration type inside the adapter. Existing upstream keys/units are preserved. Serve/Run assemble providers, scopes, runtime dependencies, callbacks, and lifecycle without validation guards or inline trust/certificate parsing. The reloader configuration initializer needs only ConfigReader; a transport factory may take the actual reloader as a runtime dependency. Logger/callback assignment in the root is acceptable.
FAIL if an interval key lacks an exposed unit, documented environment names disagree with the reader, SDK keys are renamed for cosmetic consistency, arbitrary positivity checks are added, a logger argument is required by the reloader configuration adapter, or runtime dependencies are rejected merely to enforce a reader-only signature. Mandatory paths should use throwing reads satisfied by application defaults; no secret contents belong in .env.example.
