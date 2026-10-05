---
max_turns: 20
allowed_tools: [Read, Glob, Grep, Write, Edit, Skill]
tags: [delivering, foundation]
---

We maintain a Swift 6.3 authentication library under ./acme-authentication and an application under ./acme-api. Both already pass static Linux SDK CI. Can we say they avoid full Foundation? Add the appropriate Foundation linking CI for the library on pull requests and main as ./acme-authentication/.github/workflows/foundation-linking.yml, and write ./foundation-status.md explaining the application's Foundation linkage, what its image must ship, and which APIs its own code uses. Preserve the application's chosen database and framework.

Use these verified build facts for this offline evaluation; do not resolve or build packages:

- The library has only library products. Its fresh release-consumer build lists libFoundationEssentials.so and Swift runtime libraries, with no libFoundation.so, libFoundationInternationalization.so, or lib_FoundationICU.so.
- The application uses Vapor 4.122.2 and PostgresNIO 1.33.1. Its release executable lists libFoundation.so, libFoundationInternationalization.so, lib_FoundationICU.so, and libFoundationEssentials.so. The required upstream products still use full Foundation. Neither offers a trait that removes that requirement.
- vapor/ci publishes no release tags.
- A separate OpenAPI client dependency already has its default FullFoundation trait disabled. The application's own code needs JSON decoding and ISO 8601 timestamps, with no localized display formatting.

Do not claim an action was run unless you ran it. No publishing, deployment, or release work is requested.
