---
type: llm
focus: { source: file, path: boundaries.md }
---

PASS if the note follows the repository's AGENTS.md profile: it uses `AuthenticationRPC` and `AuthenticationServer` (or does not rename them), keeps the WebAuthn standard types and the concrete `WebAuthnManager` in Core without a wrapping protocol, and keeps provider clients such as the email sender or challenge store behind Core ports.

FAIL if it renames the targets to `Authentication`/`AuthenticationGRPC`, introduces a WebAuthn protocol or adapter target, or puts a provider network client directly in Core.
