---
max_turns: 8
allowed_tools: [Read, Glob, Grep, Skill]
tags: [http, negative]
---

Our Swift catalog service serves only gRPC to other services. I need to add an internal RPC that another service calls to reserve stock for an item. How do I split it into the right proto service and map its errors to gRPC status codes?
