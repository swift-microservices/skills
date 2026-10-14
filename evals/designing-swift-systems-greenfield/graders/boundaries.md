---
type: llm
focus: { source: file, path: design.md }
---

PASS if the design states the deployment shape it recommends and why, and cuts the system into a small number of modules or services each built around one capability (for example listings, orders, payments, notifications), with buyers and sellers as users rather than as modules. If it recommends microservices, it names the module whose concrete reason earns a separate process.

FAIL if modules or services are cut per entity or per table without justification, or microservices are proposed with no module having a stated concrete reason to run alone.
