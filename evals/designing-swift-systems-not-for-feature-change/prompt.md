---
runs: 1
max_turns: 8
allowed_tools: [Read, Glob, Grep, Skill]
tags: [designing, negative]
---

Our Swift backend is a modular monolith (package acme-backend) with Users, Catalog, and Orders modules served over HTTP. Orders needs one more feature: an order's owner can archive a delivered order so it disappears from their order list, and archiving an order that has not been delivered is refused. Which targets and files do I add or change in the Orders module, and what do the use case's signature and its guard look like?
