---
type: llm
---

PASS if the report includes, each with a file reference, both findings:
- the client transport factory disables server certificate verification;
- the Temporal client is given the service reloader, so it presents the service certificate pair instead of its own `temporal.tls` pair, and needs a separate reloader.

FAIL if it proposes disabling verification, or says the Temporal client already uses its own certificate pair.
