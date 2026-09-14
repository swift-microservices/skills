---
type: llm
---

PASS if every value that crosses Temporal is declared `Codable` and `Sendable` (the workflow input, the workflow result, the query's state, every Activity input and output, and every type they hold), Activity inputs and outputs are nested under the Activity container, the workflow state and result are the only payloads declared in AccountsCore, and no Activity takes or returns an AccountsCore entity such as the registration row itself.
FAIL if any payload or a type it holds lacks `Codable`, if an Activity returns a Core entity or domain model rather than a nested output, or if Activity payloads are declared in AccountsCore.
