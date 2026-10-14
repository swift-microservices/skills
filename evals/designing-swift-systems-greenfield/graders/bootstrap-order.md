---
type: llm
focus: { source: file, path: design.md }
---

PASS if the design gives an ordered setup plan from an empty repository whose order matches its chosen shape:
- Microservices: the shared core library and the shared proto package are created and tagged before any service depends on them; then the services, a contract's owner before its consumers; then the HTTP gateway in front of them; then, where Swift apps call the gateway, a client SDK generated from the gateway's API document (optional otherwise); then library CI for the shared packages and service CI with images for the executables; then the environment (a certificate authority and workload certificates, JWT signing keys, Postgres, the Compose or platform configuration) before the first start.
- Monolith: the shared authentication, persistence, and testing code (and the protos, if it serves gRPC) start as targets inside the one package rather than as separate tagged packages; then the modules; then the HTTP or gRPC surface and the executable's composition root with its role migrations; then tests, service CI, and the image; then the environment (certificates where processes connect, JWT keys, Postgres, Compose) before the first start.
Each step says how it is known to be done, for example a build, passing tests, a tag, a rendered configuration, or a verified request.
FAIL if no setup order is given, if a service is built before a shared package it depends on exists and is tagged, if a monolith plan creates separate shared or proto packages that only its one package consumes, if CI or the environment comes before anything exists to build or run, or if the plan ends without a first start and a verification of it.
