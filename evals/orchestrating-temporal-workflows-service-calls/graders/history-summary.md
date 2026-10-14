---
type: llm
---

PASS if the reply says workflow history holds only durable business data (ids and idempotency keys), while clients, certificates, and other credentials are constructed at worker startup from configuration and mounted files, and the worker acts as itself rather than as the user.
FAIL if it says a user token or session is stored in history or needed by the worker.
