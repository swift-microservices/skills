---
type: llm
focus: { source: file, path: untangle.md }
---

PASS if the proposal keeps each invariant inside the owning module's own local transaction (the cancel-versus-restock race is resolved where the reservation is owned, for example by a guarded `WHERE` or an idempotent release), holds no transaction across a call into the other module, and states which cross-module effects are eventually consistent and how duplicates or failures are handled.

FAIL if it proposes a distributed transaction, one transaction spanning both modules' writes, a lock taken across the module boundary, or exactly-once delivery.
