---
max_turns: 20
allowed_tools: [Read, Glob, Grep, Write, Skill]
tags: [building]
---

Write a concise architecture note to ./boundaries.md for a few operations in our authentication service. Do not build a complete service or invent unrelated infrastructure.

Show Core signatures and inputs for creating an auth code, beginning passkey registration, finishing registration with a WebAuthn `RegistrationCredential`, and changing a password. Each operation affects only the signed-in user's account; creating an auth code and beginning registration need nothing from the request beyond the signed-in caller. Explain how the RPC handler supplies the caller's identity, how the authenticator-assigned credential ID is persisted, and how policy values such as code lifetimes reach the use cases.

The gateway optionally protects an entire administrative route collection with `AdminRequestContext`, checking only verified JWT role claims without database lookups. Does that replace the receiving use case's authorization?

Refresh rotation consumes a single-use row, performs one Users read with an explicit two-second deadline below the pool wait budget, and inserts the replacement in the same local transaction. Is that allowed, and would the same reasoning let us send a provider email or start a Temporal workflow inside a transaction? Auth-code creation and beginning registration only use nontransactional stores and a consumer port.
