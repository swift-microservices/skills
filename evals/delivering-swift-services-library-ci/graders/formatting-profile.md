---
type: llm
---

PASS if .swift-format is copied exactly from the skill's Temporal library asset, keeps the
150-column limit and ordered imports, and the generated Swift files follow that profile. A
documentation requirement may remain in AGENTS.md without changing the formatter's rule values.
FAIL if the agent substitutes the service's 400-column default, Configuration's 120-column file,
or an approximation that alters Temporal's enabled/disabled rules.
