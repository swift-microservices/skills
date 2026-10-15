---
runs: 1
max_turns: 40
timeout_seconds: 900
allowed_tools: [Read, Glob, Grep, Write, Edit, Skill]
tags: [building, tests]
---

Our catalog service in ./acme-catalog has no tests yet. Add the test target for its Core module and cover CreateItemUseCase and GetItemUseCase: an administrator creating an item, a non-administrator being refused, the bad name and bad idempotency key refusals, a duplicate name, a create retried with the same idempotency key but a different name, and looking up an item that doesn't exist. Our MockDatabase lives in the AcmeTesting product of acme-core.

Put the test doubles and the helper that builds a signed-in caller in Tests/CatalogCoreTests/Mocks/ItemUseCaseMocks.swift, the helper that hands a test its database in Tests/CatalogCoreTests/Mocks/WithDatabase.swift, shared fixed values in Tests/CatalogCoreTests/Support/Values.swift, and the tests in Tests/CatalogCoreTests/ItemUseCaseTests.swift. Don't run swift build or swift test; I'll run them.
