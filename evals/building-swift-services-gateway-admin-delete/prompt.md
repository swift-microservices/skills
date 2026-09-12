---
max_turns: 60
allowed_tools: [Read, Glob, Grep, Write, Edit, Skill]
tags: [building, gateway]
---

In our Hummingbird gateway (package acme-api, targets API and Acme), items are read at GET /v1/items and GET /v1/items/:id by anyone, and the ItemController already holds an Acme_Catalog_V1_ItemService client. Add an administrator-only route that deletes an item. Write the changes under ./acme-api and explain where the administrator check happens.
