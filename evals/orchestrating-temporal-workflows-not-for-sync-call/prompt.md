---
max_turns: 8
allowed_tools: [Read, Glob, Grep, Skill]
tags: [temporal, negative]
---

In our Swift catalog service, the ListItems RPC should also return each item's current price from the pricing service. It's a simple synchronous lookup. How should the catalog service call pricing, and where does that client get constructed?
