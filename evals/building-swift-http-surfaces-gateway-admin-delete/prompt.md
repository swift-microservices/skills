---
max_turns: 60
allowed_tools: [Read, Glob, Grep, Write, Edit, Skill]
tags: [http, gateway]
---

In our Hummingbird gateway (package acme-api, targets API and Acme), items are read at GET /v1/items and GET /v1/items/:id by anyone, and the ItemController already holds an Acme_Catalog_V1_ItemService client. Add an administrator-only route that deletes an item. Write the changes under ./acme-api, putting any new request context in Sources/API/Contexts/, and explain where the administrator check happens. The package is an abridged excerpt (error handling, response schemas, and the serve command are omitted), so don't try to build it.
