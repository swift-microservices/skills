---
type: llm
focus: { source: file, path: AGENTS.md }
---

PASS if AGENTS.md records the Foundation-related exception with all three of: the dependency or generated code that forces full Foundation (for example OpenAPIURLSession behind the URLSessionTransport trait, the OpenAPI runtime, or the generator's output), the version it was observed at (a resolved version, or the manifest's floor such as `from: "1.12.1"`, not just the dependency's name), and the replacement coverage that still runs (for example which products or trait configurations stay checked, the consumer builds, release and static SDK builds).
FAIL if any of the three is missing, the exception is a bare statement that the package needs Foundation, or it claims the custom-transport configuration is Foundation-free without a linkage check.
