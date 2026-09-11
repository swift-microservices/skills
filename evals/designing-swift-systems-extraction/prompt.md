---
max_turns: 15
allowed_tools: [Read, Glob, Grep, Write, Skill]
tags: [designing]
---

We have a Swift modular monolith with a Newsletter module: a subscribers table in a `newsletter` schema, a SubscribeUseCase and ListSubscribersUseCase, and the web layer calls them directly. We want to pull it out into its own service without breaking the web layer. Write a step-by-step plan to ./extraction-plan.md, in the order the steps must happen, and say which steps must not be done without an explicit decision from us.
