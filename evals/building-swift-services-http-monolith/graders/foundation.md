---
type: llm
---

PASS if generated Swift uses FoundationEssentials where Foundation values are needed, directly or with a supported-SDK Foundation fallback, and avoids introducing legacy formatter/date-decoding APIs or String(format:). Hummingbird's FullFoundation defaults must be disabled while keeping ConfigurationSupport if its configuration integration is used, and OpenAPI runtime defaults must be disabled when that dependency is present. Judge the actual generated manifest and API usages, not just a statement in the summary. It is acceptable that required PostgresNIO still links full Foundation; the reply must not promise that the whole application is Essentials-only without dependency/linking evidence.
FAIL if local legacy Foundation APIs are justified by the database already linking Foundation, if required traits/features are dropped to get traits: [], or if current transitive linkage is described as proof that local code cannot use modern Essentials APIs.
