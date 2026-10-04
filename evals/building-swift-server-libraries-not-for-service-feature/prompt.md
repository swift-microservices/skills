---
max_turns: 8
allowed_tools: [Read, Glob, Grep, Skill]
tags: [libraries, negative]
---

Our Swift orders service (targets OrdersCore, OrdersPostgres, OrdersGRPC, Orders) needs a CancelOrder use case that only the order's owner may call, guarded so a shipped order cannot be cancelled. Which files do I add, and how should the use case signature look?
