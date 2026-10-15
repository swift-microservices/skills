---
runs: 1
max_turns: 25
timeout_seconds: 600
allowed_tools: [Read, Glob, Grep, Write, Skill]
tags: [designing, events]
---

Our Swift backend is a modular monolith, package acme-shop: one process, one Postgres database, with Orders, Notifications, and Loyalty modules. When an order is placed, Notifications emails a receipt and Loyalty awards points. Today PlaceOrderUseCase saves the order and then calls both modules directly. Last week our email provider was down and checkouts failed, and a deploy restart right after some orders were saved meant those customers never got their points. How should Orders tell the other two modules? We'd like to move Notifications into its own service next year. Write the design to ./events.md and summarize it.
