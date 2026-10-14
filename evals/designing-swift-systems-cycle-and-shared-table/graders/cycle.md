---
type: llm
focus: { source: file, path: untangle.md }
---

PASS if the proposal leaves the module dependencies pointing one way and breaks the reverse synchronous edge in a way the design names: by moving ownership, by extracting a third module, or by turning it into a fact the other side reacts to (such as a stock-replenished event Orders consumes through an outbox, consumed idempotently); and no module imports another module's targets, with ports in the consumer's Core satisfied in the composition root.

FAIL if the cycle remains (each module still calls the other synchronously), it is hidden behind a lazy reference or a closure injected later, or modules in the one process call each other over gRPC or HTTP.
