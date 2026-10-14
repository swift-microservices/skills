---
type: llm
focus: { source: file, path: acme-library/Sources/Acme/Serve/Serve.swift }
---

PASS if the composition root builds the members use case the loans module depends on first, wraps it in an adapter value conforming to the loans module's port (a type defined in the executable, not in a Members or Loans target), and passes that adapter into the borrowing use case's initializer. The adapter's definition may live in another file of the executable; Serve.swift only has to construct and inject it.

FAIL if the borrowing use case receives a members use case, repository, or database directly; if the port is satisfied over the network (a gRPC client) inside this one process; or if no member check is wired into the borrowing use case.
