---
type: regex
target: { source: file, path: acme-backend/Sources/CatalogPostgres/Migrations/Item/CreateItemsTable.swift }
pattern: 'id\s+UUID\s+PRIMARY\s+KEY\s+DEFAULT\s+(uuidv7|gen_random_uuid)\(\)'
flags: i
---
