---
type: llm
focus: { source: file, path: Sources/CatalogWebhooks/ItemCreatedPayload.swift }
---

PASS if `ItemCreatedPayload` is a value type with `itemId`, `name`, and `priceCents` fields whose encoded keys are exactly `itemId`, `name`, and `priceCents`, and it is made from an `Item` by an initializer on `ItemCreatedPayload` (for example `init(item: Item)`, possibly in an extension) that writes the item id as a lowercased UUID string.
FAIL if the file is missing or empty, the conversion is a method or property on `Item` (such as `item.payload` or `item.toPayload()`), or the id is not lowercased.
Grade only against these criteria; do not fail for issues they do not mention.
