---
max_turns: 20
allowed_tools: [Read, Glob, Grep, Write, Skill]
tags: [building]
---

/swift-microservices:building-swift-services

Write a concise architecture note to ./boundaries.md for these Authentication operations. The applicable AGENTS.md defines a project profile that overrides general skill defaults: `AuthenticationRPC` and `AuthenticationServer` avoid dependency module collisions, and WebAuthn standard types and its concrete manager remain in Core because wrapping them adds no useful seam. Do not build a complete service or invent unrelated infrastructure.

Show Core signatures and inputs for creating an auth code, beginning passkey registration, finishing registration with a WebAuthn `RegistrationCredential`, and changing a password. Each operation affects only the signed-in user's account. Explain how the RPC handler supplies caller identity, how the authenticator-assigned credential ID is persisted, and how policy values reach use cases.

The gateway optionally protects an entire administrative route collection with `AdminRequestContext`, checking only verified JWT role claims without database lookups. Explain whether this replaces the receiving use case's authorization.

Refresh rotation consumes a single-use row, performs one Users read with an explicit two-second deadline below the pool wait budget, and inserts the replacement in the same local transaction. Explain when this exception is valid and whether it also permits provider writes or Temporal calls inside transactions. Auth-code creation and beginning registration only use nontransactional stores and a consumer port.
