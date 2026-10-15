---
runs: 1
max_turns: 40
timeout_seconds: 600
allowed_tools: [Read, Glob, Grep, Write, Edit, Skill]
tags: [writing, conformances, concurrency]
---

Our catalog service needs to tell a partner whenever an item is created. In the CatalogWebhooks target, add:

- Sources/CatalogWebhooks/ItemCreatedPayload.swift: the JSON body we send, `{"itemId": "<lowercased item id>", "name": "<name>", "priceCents": <int>}`, made from a CatalogCore `Item`.
- Sources/CatalogWebhooks/WebhookNotifier.swift: a notifier configured with the partner URL and a `WebhookTransport`, whose `notify` posts the body for an item. A 2xx response counts as delivered; a 4xx is given up and logged; a 5xx or a thrown transport error is retried once, then logged and given up. It logs through swift-log.
- Sources/CatalogWebhooks/DeliveryLog.swift: the record of delivered item ids, so the same item is never posted twice even when two requests for it race. A failed delivery must not count as delivered.

Networking and dependency resolution are unavailable, so don't build. Finish with a short summary.
