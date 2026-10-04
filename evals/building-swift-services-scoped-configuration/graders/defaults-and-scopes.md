---
type: llm
focus: { source: file, path: acme-catalog/Sources/Catalog/Configuration/InMemoryProvider+ApplicationDefaults.swift }
---

PASS if Catalog's application defaults are an `InMemoryProvider` extension that holds the service credential paths under a `tls` scope (`/run/catalog-peer/...`) and the Temporal credential paths under a separate `temporal.tls` scope (`/run/catalog-temporal/...`), as relative keys such as `certificatePath`, `privateKeyPath`, and `trustRootsPath`.

FAIL if both pairs share one scope, the paths are missing, or a boolean selects which pair Temporal uses.
