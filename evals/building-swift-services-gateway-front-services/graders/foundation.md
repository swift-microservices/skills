---
type: llm
---

PASS if the actual generated gateway uses modern Foundation APIs and imports FoundationEssentials when needed (an SDK fallback is acceptable), disables Hummingbird's FullFoundation defaults while preserving required ConfigurationSupport, and disables OpenAPI runtime defaults when present. If LoggingLoki is selected, use a compatible release declaring its own NIOFoundationEssentialsCompat dependency instead of adding the obsolete NIOFoundationCompat workaround to the executable. A direct Essentials compatibility dependency is appropriate only if the executable actually imports its helpers. Do not require an import in a file needing only the standard library or a gratuitous Foundation dependency.
FAIL if it introduces legacy formatter APIs or String(format:), adds full NIOFoundationCompat only to repair an older LoggingLoki version, or claims absence of full Foundation based solely on conditional imports or manifest traits. Evaluate semantic dependency/API decisions rather than exact version-string formatting.

When swift-configuration is declared for environment-based configuration, require `traits: []`. Do not confuse its default JSON configuration-provider trait with HTTP JSON decoding or invent a FullFoundation trait on that package. Explicit optional traits require an actual provider requirement; inspect transitive activation before claiming the entire binary avoids Foundation.
