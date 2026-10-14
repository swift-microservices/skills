---
type: llm
focus: { source: file, path: design.md }
---

PASS if the design reserves an event (published through an outbox in the order's transaction) for the order-event fan-out to email and push, and a durable workflow or an equally durable mechanism for the multi-step payment and payout process, each with a stated reason; and synchronous calls are local use-case calls through ports in a monolith or gRPC between services.

FAIL if a message broker or workflow engine is introduced with no stated requirement, a broker is added while every consumer runs in one process, or modules call each other over HTTP or gRPC inside one process.
