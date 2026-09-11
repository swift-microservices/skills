---
max_turns: 30
allowed_tools: [Read, Glob, Grep, Write, Edit, Skill]
tags: [temporal]
---

Our Swift service "accounts" (package acme-accounts, targets AccountsCore, AccountsPostgres, AccountsGRPC, Accounts, on grpc-swift and PostgresNIO) creates a registration row when someone signs up. We need the registration to send a verification email, wait up to 24 hours for the person to click the link, and mark the registration expired if they never do. Add the durable part of this with the Swift Temporal SDK, including whatever process runs it. Write the new files under ./acme-accounts and finish with a short summary of what runs where.
