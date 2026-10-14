---
max_turns: 25
timeout_seconds: 600
allowed_tools: [Read, Glob, Grep, Write, Skill]
tags: [designing, modules]
---

Our Swift backend is a modular monolith, package acme-store, with Orders and Inventory modules in one Postgres database. PlaceOrderUseCase calls Inventory's ReserveStockUseCase before it saves an order. RestockUseCase in Inventory calls Orders' ListBackorderedOrdersUseCase and then marks those orders ready to ship. Both modules write the stock_reservations table directly: Inventory inserts a row when it reserves stock, and Orders deletes rows when an order is cancelled. The two modules now import each other, and last week a cancellation and a restock raced and left a reservation behind for an order that no longer exists. How should we untangle this? Write the proposal to ./untangle.md and flag anything you need us to decide.
