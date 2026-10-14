---
max_turns: 25
timeout_seconds: 600
allowed_tools: [Read, Glob, Grep, Write, Edit, Skill]
tags: [writing, foundation]
---

Sources/BillingCore/InvoiceText.swift in this Swift server package still uses ISO8601DateFormatter, DateFormatter, NumberFormatter, and String(format:), and it imports Foundation directly, so the Linux build pulls in full Foundation for it. Rewrite it the way our server code should be written, keeping every function's signature and its exact output, including the cases in Tests/BillingCoreTests/InvoiceTextTests.swift, which must keep passing unchanged.

Networking and dependency resolution are unavailable, so don't build or run the tests. Summarize which API replaced each legacy call and what still needs verification on Linux.
