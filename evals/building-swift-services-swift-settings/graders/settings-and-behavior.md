---
type: llm
---

PASS only if all owned Swift library, executable, and test targets use the four upcoming features through one stored shared settings array, Swift 6 mode remains explicit, and the explanation correctly distinguishes tools version, language mode, and default isolation. No blanket MainActor default, unsafe flags, or diagnostic suppression. Explain each feature briefly and accurately; public import is not a re-export.

The migrated sources must preserve the public API and behavior: explicitly import the extension provider in the using file, use any for the existential without rewriting generic constraints as existentials, expose UtilityCore at the required import access, and keep both OperationRunner.run and its witness plain nonescaping async callbacks. No @Sendable, @concurrent, detached task, unchecked conformance, or serial actor replacing the callback contract.

Require meaningful tests that use a non-Sendable reference from a custom actor and MainActor through the scoped operation, including suspension and a thrown error. A successful compiler/test run is required when a compatible toolchain is available; an environment failure is reported as such, never a claimed pass. Do not grade headings or exact wording.
