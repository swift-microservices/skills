---
type: llm
focus: { source: file, path: AGENTS.md }
---

PASS if AGENTS.md has a `## CI` section that names the standard library CI and records exactly these exceptions, each with its reason: the tests run in the repository's own workflow beside PostgreSQL because the shared test workflow cannot attach a database, and there is no Foundation-linking job because the package's only library product links full Foundation through PostgresNIO.
FAIL if the section is missing, an exception has no reason, or it claims the Foundation-linking check runs with the product excluded.
