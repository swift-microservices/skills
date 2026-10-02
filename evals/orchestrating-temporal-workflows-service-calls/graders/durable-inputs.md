---
type: llm
---

PASS if persisted Activity/workflow payloads contain stable business identifiers and idempotency data, not user JWTs or live credentials, and retries reuse that data. Workflow execution remains deterministic; network/database work happens in Activities through Core ports. The accounts internal handler invokes an input-only use case with business invariants and no application process principal. User IDs, if present, describe affected business data and do not become an authenticated subject.
FAIL if the worker needs a current user session, stores bearer credentials in history, mints a process token, passes certificate-derived subjects into Core, or directly accesses accounts tables.
